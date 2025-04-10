import { createPublicClient, createWalletClient, http, parseEther } from "viem";
import { celo, celoAlfajores } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import * as fs from "fs";
import * as path from "path";
import { config } from "./config";
import { deriveRelayerAccount } from "./utils";
import getSecret from "./get-secret";

const MIN_BALANCE_THRESHOLD = 5;
const TRANSFER_AMOUNT = 50;

const networks = {
  mainnet: {
    name: "mainnet",
    chain: celo,
    rpcUrl: "https://forno.celo.org",
    relayerAddressesFile: "infra/relayer_addresses.json",
    relayerAddressesKey: "prod",
  },
  alfajores: {
    name: "alfajores",
    chain: celoAlfajores,
    rpcUrl: "https://alfajores-forno.celo-testnet.org",
    relayerAddressesFile: "infra/relayer_addresses.json",
    relayerAddressesKey: "staging",
  },
} as const;

type NetworkType = keyof typeof networks;

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
  const networkArg = process.argv[2];
  if (!networkArg || !(networkArg in networks)) {
    console.log("Usage: pnpm refill:mainnet or pnpm refill:alfajores");
    process.exit(1);
  }

  const network = networks[networkArg as NetworkType];
  console.log(`Refilling relayer accounts on ${network.name}...`);

  const relayerAddressesPath = path.resolve(
    process.cwd(),
    network.relayerAddressesFile,
  );
  const relayerAddressesData = JSON.parse(
    fs.readFileSync(relayerAddressesPath, "utf8"),
  ) as Record<string, Record<string, string>>;
  const relayerAddresses = relayerAddressesData[network.relayerAddressesKey];

  const privateKey = process.env.REFILLER_PRIVATE_KEY;
  if (!privateKey) {
    console.error(
      "Error: REFILLER_PRIVATE_KEY environment variable is not set",
    );
    process.exit(1);
  }

  const account = privateKeyToAccount(`0x${privateKey}`);
  const publicClient = createPublicClient({
    chain: network.chain,
    transport: http(network.rpcUrl),
  });
  const walletClient = createWalletClient({
    account,
    chain: network.chain,
    transport: http(network.rpcUrl),
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
          chain: network.chain,
        });
        await publicClient.waitForTransactionReceipt({ hash });

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
