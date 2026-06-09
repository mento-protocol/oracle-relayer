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
  polygonAmoy,
} from "viem/chains";
import { config } from "./config";
import getSecret from "./get-secret";
import { deriveRelayerAccount } from "./utils";

const MIN_BALANCE_THRESHOLD = 50;
const TRANSFER_AMOUNT = 50;

// Gas feeds (the CELO_XXX feeds, except CELO/USD) relay at most once per day, so
// they burn through CELO far more slowly. They get a lower refill threshold but
// the same top-up amount.
const GAS_FEED_MIN_BALANCE_THRESHOLD = 5;
const GAS_FEED_TRANSFER_AMOUNT = 10;

const chains: Record<string, Chain> = {
  celo,
  "celo-sepolia": celoSepolia,
  monad,
  "monad-testnet": monadTestnet,
  "polygon-testnet": polygonAmoy,
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

async function main() {
  const chainArg = process.argv[2];
  if (!chainArg || !(chainArg in chains)) {
    console.log(
      "Usage: pnpm refill:celo | pnpm refill:celo-sepolia | pnpm refill:monad | pnpm refill:monad-testnet | pnpm refill:polygon-testnet [--dry-run]",
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
  for (const [rateFeedKey] of Object.entries(relayerAddresses)) {
    const rateFeedName = convertRateFeedFormat(rateFeedKey);
    const relayerAccount = deriveRelayerAccount(mnemonic, rateFeedName);

    // Gas feeds only get the relaxed threshold on celo mainnet, where the
    // once-per-day relay economics apply.
    const gasFeed = chainArg === "celo" && isGasFeed(rateFeedKey);
    const threshold = gasFeed
      ? GAS_FEED_MIN_BALANCE_THRESHOLD
      : MIN_BALANCE_THRESHOLD;
    const transferAmount = gasFeed ? GAS_FEED_TRANSFER_AMOUNT : TRANSFER_AMOUNT;

    const balance = await publicClient.getBalance({
      address: relayerAccount.address,
    });
    const balanceInNative = Number(balance) / 1e18;

    console.log(
      `${rateFeedKey}: ${relayerAccount.address} - Balance: ${balanceInNative.toFixed(4)} ${symbol}`,
    );

    if (balanceInNative < threshold) {
      console.log(
        `  Low balance detected. ${dryRun ? "Would transfer" : "Transferring"} ${transferAmount.toString()} ${symbol}...`,
      );

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
        console.error(
          `  Error transferring ${symbol} to ${rateFeedKey}:`,
          error,
        );
      }
    } else {
      console.log(`  Balance is sufficient.`);
    }
  }

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
