import * as fs from "fs";
import * as path from "path";
import {
  Chain,
  createPublicClient,
  createWalletClient,
  http,
  parseEther,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import {
  celo,
  celoSepolia,
  monad,
  monadTestnet,
  polygon,
  polygonAmoy,
} from "viem/chains";
import { config } from "./config";
import getSecret from "./get-secret";
import { deriveRelayerAccount } from "./utils";

// Refill thresholds are expressed in days of runway rather than a flat token
// amount, because burn per relayer differs by ~10x between feed classes on the
// same chain and by ~100x between chains (a Polygon relayer burns ~135 POL/day,
// a Celo gas feed ~0.05 CELO/day). A relayer is topped up when its balance
// covers fewer than MIN_RUNWAY_DAYS of relaying, and the top-up brings it to
// TARGET_RUNWAY_DAYS. Keep MIN_RUNWAY_DAYS comfortably above the interval at
// which this script is run: an address just above the threshold on one run has
// to survive until the next one.
const MIN_RUNWAY_DAYS = 7;
const TARGET_RUNWAY_DAYS = 14;

// Gas feeds (the CELO_XXX feeds, except CELO/USD) relay once a day, so a few
// tokens last months. Longer horizons keep the refills rare but meaningful.
const GAS_FEED_MIN_RUNWAY_DAYS = 30;
const GAS_FEED_TARGET_RUNWAY_DAYS = 90;

// Native tokens burned per relayer per weekday (relays per weekday x average
// cost per relay, rounded up), measured on-chain on 2026-09-03. Re-measure
// when gas prices or relay cadence change materially.
//
// How burn is determined. The scheduler triggers every feed once a minute, but
// the relayer contract only accepts a report when the Chainlink aggregator has
// a round newer than the last one relayed (it reverts with TimestampNotNew
// otherwise). So the relay count is set by how often Chainlink publishes a new
// round, and gas per relay is nearly identical for every feed on a chain. Two
// things make some feeds burn more than others:
//
//   1. Composite feeds (euroc_eur, eur_xof on Celo) are built from two
//      aggregators and relay whenever EITHER one has a new round, so they run
//      at roughly twice the pace of a single-aggregator feed.
//   2. The Chainlink round cadence itself differs per chain and per feed:
//      ~4.5 min for every feed on Celo and Monad, ~1 min on Polygon, and
//      ~1 hour for the Monad stablecoin feeds (ausd/usdc/usdt).
//
// Weekends: fiat xxx/usd feeds are rejected on-chain by the MarketHoursBreaker
// ("FX market is closed") from Friday ~21:00 UTC to Sunday ~22:00 UTC, while
// crypto/stablecoin feeds and the composite feeds (which the breaker does not
// cover) keep relaying. That lowers the fiat feeds' weekly average but not
// their weekday burn, and a relayer has to survive any five-weekday stretch,
// so the figures below are weekday burn.
const DAILY_COST: Record<
  string,
  { default: number; feeds?: Record<string, number> }
> = {
  // ~0.045 CELO/relay x ~320 relays per weekday = ~14.4 for every
  // single-aggregator feed (fiat and crypto alike).
  celo: {
    default: 15,
    feeds: {
      // EURC/EUR is derived from two Chainlink aggregators, EURC/USD and
      // EUR/USD (inverted). The relayer reports whenever either aggregator
      // has a new round, so it relays ~570 times a day: ~0.045 x 570 = ~26.
      // It is also not covered by the MarketHoursBreaker, so it keeps that
      // pace over the weekend.
      euroc_eur: 26,
      // EUR/XOF is likewise derived from EUR/USD and XOF/USD (inverted), so
      // it relays on every new round of either aggregator (~570/day) and is
      // not paused by the MarketHoursBreaker on weekends.
      eur_xof: 26,
    },
  },
  // ~0.09 POL/relay x ~1,430 relays per weekday (a new Chainlink round every
  // minute) = ~130.
  polygon: { default: 135 },
  // ~0.064 MON/relay x ~345 relays per weekday = ~22 for the fiat feeds
  // (eur/gbp/chf/jpy), whose aggregators publish a new round every ~4.5 min.
  monad: {
    default: 22,
    feeds: {
      // The Chainlink aggregators for the three stablecoin feeds on Monad only
      // publish a new round once an hour, so the relayer contract accepts just
      // 24 relays a day: ~0.058 x 24 = ~1.4 MON.
      ausd_usd: 1.5,
      usdc_usd: 1.5,
      usdt_usd: 1.5,
    },
  },
  // Testnets relay once a day, so ~1 token/day is generous.
  "celo-sepolia": { default: 1 },
  "monad-testnet": { default: 1 },
  "polygon-testnet": { default: 1 },
};
// Gas feeds are scheduled once a day (see infra/scheduler.tf) rather than
// every minute, so they burn a single relay's worth of CELO per day.
const GAS_FEED_DAILY_COST = 0.05;

// viem's default Amoy RPC (https://rpc-amoy.polygon.technology) stopped
// resolving in DNS. This script reads chain.rpcUrls.default.http[0] directly,
// so override the chain's default endpoint with a working public node
// (mirrors relay.ts and update-mock-aggregators.ts).
const polygonAmoyWithWorkingRpc: Chain = {
  ...polygonAmoy,
  rpcUrls: {
    ...polygonAmoy.rpcUrls,
    default: { http: ["https://polygon-amoy.drpc.org"] },
  },
};

const chains: Record<string, Chain> = {
  celo,
  "celo-sepolia": celoSepolia,
  monad,
  "monad-testnet": monadTestnet,
  "polygon-testnet": polygonAmoyWithWorkingRpc,
  polygon,
} as const;

/**
 * Converts a rate feed key from the JSON format (lowercase with underscores)
 * to the format used for deriving relayer accounts (uppercase with slashes)
 *
 * @param rateFeedKey The rate feed key from the JSON file (e.g., "celo_php")
 * @returns The rate feed name in the format used for deriving accounts (e.g., "CELO/PHP")
 */
function convertRateFeedFormat(rateFeedKey: string): string {
  const parts = rateFeedKey.split("_").map((part) => part.toUpperCase());
  return parts.join("/");
}

/**
 * Whether a rate feed is a gas feed, i.e. a CELO_XXX feed other than CELO/USD.
 * These relay at most once per day and so use a lower refill threshold.
 *
 * @param rateFeedKey The rate feed key from the JSON file (e.g., "celo_php")
 * @returns true if the feed is a gas feed
 */
function isGasFeed(rateFeedKey: string): boolean {
  return rateFeedKey.startsWith("celo_") && rateFeedKey !== "celo_usd";
}

interface RunwayRow {
  rateFeed: string;
  balance: number;
  costPerDay: number;
  runwayDays: number;
  action: string;
}

/**
 * Prints every relayer sorted by runway (shortest first) so the operator can
 * see which addresses are close to the threshold even when nothing was sent.
 */
function printRunwayTable(rows: RunwayRow[], symbol: string): void {
  const sorted = [...rows].sort((a, b) => a.runwayDays - b.runwayDays);
  const feedWidth = Math.max(...sorted.map((r) => r.rateFeed.length), 4);
  const header = `${"feed".padEnd(feedWidth)}  ${`balance (${symbol})`.padStart(16)}  ${`${symbol}/day`.padStart(9)}  ${"runway".padStart(9)}  action`;
  console.log(`\nRunway per relayer (shortest first):\n${header}`);
  for (const r of sorted) {
    console.log(
      `${r.rateFeed.padEnd(feedWidth)}  ${r.balance.toFixed(2).padStart(16)}  ${r.costPerDay.toString().padStart(9)}  ${`${r.runwayDays.toFixed(1)} d`.padStart(9)}  ${r.action}`,
    );
  }
}

async function main() {
  const chainArg = process.argv[2];
  if (!chainArg || !(chainArg in chains)) {
    console.log(
      "Usage: pnpm refill:celo | pnpm refill:celo-sepolia | pnpm refill:monad | pnpm refill:monad-testnet | pnpm refill:polygon-testnet | pnpm refill:polygon [--dry-run]",
    );
    process.exit(1);
  }

  const dryRun = process.argv.includes("--dry-run");
  const chain = chains[chainArg];
  const symbol = chain.nativeCurrency.symbol;
  console.log(
    `Refilling relayer accounts on ${chainArg}${dryRun ? " (dry run)" : ""}...`,
  );

  const relayerAddressesPath = path.resolve(
    process.cwd(),
    "infra/relayer_addresses.json",
  );
  const relayerAddressesData = JSON.parse(
    fs.readFileSync(relayerAddressesPath, "utf8"),
  ) as Record<string, Record<string, string>>;
  const relayerAddresses = relayerAddressesData[chainArg];

  const privateKey = process.env.REFILLER_PRIVATE_KEY;
  if (!privateKey) {
    console.error(
      "Error: REFILLER_PRIVATE_KEY environment variable is not set",
    );
    process.exit(1);
  }

  const account = privateKeyToAccount(`0x${privateKey}`);
  const publicClient = createPublicClient({
    chain,
    transport: http(chain.rpcUrls.default.http[0]),
  });
  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(chain.rpcUrls.default.http[0]),
  });

  const mnemonic = await getSecret(config.RELAYER_MNEMONIC_SECRET_ID);

  const transfersMade = [];
  const runwayRows: RunwayRow[] = [];
  for (const [rateFeedKey] of Object.entries(relayerAddresses)) {
    const rateFeedName = convertRateFeedFormat(rateFeedKey);
    const relayerAccount = deriveRelayerAccount(mnemonic, rateFeedName);

    // Gas feeds only get the relaxed thresholds on celo mainnet, where the
    // once-per-day relay economics apply.
    const gasFeed = chainArg === "celo" && isGasFeed(rateFeedKey);
    const costPerDay = gasFeed
      ? GAS_FEED_DAILY_COST
      : (DAILY_COST[chainArg].feeds?.[rateFeedKey] ??
        DAILY_COST[chainArg].default);
    const minRunwayDays = gasFeed ? GAS_FEED_MIN_RUNWAY_DAYS : MIN_RUNWAY_DAYS;
    const targetRunwayDays = gasFeed
      ? GAS_FEED_TARGET_RUNWAY_DAYS
      : TARGET_RUNWAY_DAYS;
    const threshold = costPerDay * minRunwayDays;
    const targetBalance = costPerDay * targetRunwayDays;

    const balance = await publicClient.getBalance({
      address: relayerAccount.address,
    });
    const balanceInNative = Number(balance) / 1e18;
    const runwayDays = balanceInNative / costPerDay;

    console.log(
      `${rateFeedKey}: ${relayerAccount.address} - Balance: ${balanceInNative.toFixed(4)} ${symbol} (~${runwayDays.toFixed(1)} days at ${String(costPerDay)} ${symbol}/day)`,
    );

    const row: RunwayRow = {
      rateFeed: rateFeedKey,
      balance: balanceInNative,
      costPerDay,
      runwayDays,
      action: "ok",
    };
    runwayRows.push(row);

    if (balanceInNative < threshold) {
      // Top up to the target rather than sending a fixed amount. Precision is
      // not important here, so round up and add one token of slack.
      const transferAmount = Math.ceil(targetBalance - balanceInNative) + 1;
      console.log(
        `  Below ${String(minRunwayDays)}-day threshold (${threshold.toFixed(2)} ${symbol}). ${dryRun ? "Would transfer" : "Transferring"} ${transferAmount.toString()} ${symbol} to reach ~${String(targetRunwayDays)} days...`,
      );
      row.action = dryRun
        ? `would send ${String(transferAmount)}`
        : `send ${String(transferAmount)}`;

      if (dryRun) {
        transfersMade.push({
          rateFeed: rateFeedKey,
          address: relayerAccount.address,
          amount: transferAmount,
          hash: "(dry run — not submitted)",
        });
        continue;
      }

      try {
        const hash = await walletClient.sendTransaction({
          to: relayerAccount.address,
          value: parseEther(transferAmount.toString()),
          chain,
        });
        await publicClient.waitForTransactionReceipt({ hash });

        console.log(`  Transaction sent: ${hash}`);
        transfersMade.push({
          rateFeed: rateFeedKey,
          address: relayerAccount.address,
          amount: transferAmount,
          hash,
        });
      } catch (error) {
        row.action = `FAILED to send ${String(transferAmount)}`;
        console.error(
          `  Error transferring ${symbol} to ${rateFeedKey}:`,
          error,
        );
      }
    } else {
      console.log(`  Balance is sufficient.`);
    }
  }

  printRunwayTable(runwayRows, symbol);

  if (transfersMade.length > 0) {
    console.log("\nTransfers made:");
    for (const transfer of transfersMade) {
      console.log(
        `- ${transfer.rateFeed}: ${String(transfer.amount)} ${symbol} to ${transfer.address} (tx: ${transfer.hash})`,
      );
    }
  } else {
    console.log(
      "\nNo transfers were needed. All relayer accounts have sufficient balance.",
    );
  }
}

void main();
