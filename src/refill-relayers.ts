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
import { celo, celoSepolia, monadTestnet } from "viem/chains";
import { config } from "./config";
import getSecret from "./get-secret";
import { deriveRelayerAccount } from "./utils";

const MIN_BALANCE_THRESHOLD = 5;
const TRANSFER_AMOUNT = 50;

const chains: Record<string, Chain> = {
  celo,
  "celo-sepolia": celoSepolia,
  "monad-testnet": monadTestnet,
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

async function main() {
  const chainArg = process.argv[2];
  if (!chainArg || !(chainArg in chains)) {
    console.log("Usage: pnpm refill:celo or pnpm refill:celo-sepolia");
    process.exit(1);
  }

  const chain = chains[chainArg];
  console.log(`Refilling relayer accounts on ${chainArg}...`);

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
    const balance = await publicClient.getBalance({
      address: relayerAccount.address,
    });
    const balanceInCelo = Number(balance) / 1e18;

    console.log(
      `${rateFeedKey}: ${relayerAccount.address} - Balance: ${balanceInCelo.toFixed(4)} CELO`,
    );

    if (balanceInCelo < MIN_BALANCE_THRESHOLD) {
      console.log(
        `  Low balance detected. Transferring ${TRANSFER_AMOUNT.toString()} CELO...`,
      );

      try {
        const hash = await walletClient.sendTransaction({
          to: relayerAccount.address,
          value: parseEther(TRANSFER_AMOUNT.toString()),
          chain,
        });
        await publicClient.waitForTransactionReceipt({ hash });
        // let hash = "0x1234567890";

        console.log(`  Transaction sent: ${hash}`);
        transfersMade.push({
          rateFeed: rateFeedKey,
          address: relayerAccount.address,
          amount: TRANSFER_AMOUNT,
          hash,
        });
      } catch (error) {
        console.error(`  Error transferring CELO to ${rateFeedKey}:`, error);
      }
    } else {
      console.log(`  Balance is sufficient.`);
    }
  }

  if (transfersMade.length > 0) {
    console.log("\nTransfers made:");
    for (const transfer of transfersMade) {
      console.log(
        `- ${transfer.rateFeed}: ${String(transfer.amount)} CELO to ${transfer.address} (tx: ${transfer.hash})`,
      );
    }
  } else {
    console.log(
      "\nNo transfers were needed. All relayer accounts have sufficient balance.",
    );
  }
}

void main();
