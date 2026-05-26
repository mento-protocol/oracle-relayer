import type { Address, Chain, PublicClient } from "viem";
import {
  createPublicClient,
  createWalletClient,
  getAddress,
  getContract,
  http,
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
import type { Logger } from "winston";

import { chainlinkAggregatorAbi } from "./chainlink-aggregator-abi";
import getSecret from "./get-secret";
import { mockAggregatorBatchReporterAbi } from "./mock-aggregator-batch-reporter-abi";
import MockAggregatorMappingsJson from "./mock-aggregator-mappings.json";

type ChainName =
  | "celo"
  | "celo-sepolia"
  | "monad"
  | "monad-testnet"
  | "polygon"
  | "polygon-testnet";
type AggregatorMapping = Record<
  string,
  {
    mainnet: Address;
    testnet: Address;
  }
>;
type AllAggregatorMappings = Partial<Record<ChainName, AggregatorMapping>>;

const chainMap: Record<ChainName, Chain> = {
  celo,
  "celo-sepolia": celoSepolia,
  monad,
  "monad-testnet": monadTestnet,
  polygon,
  "polygon-testnet": polygonAmoy,
};

const publicClients = new Map<ChainName, PublicClient>();
const aggregatorMappings = MockAggregatorMappingsJson as AllAggregatorMappings;
const mockAggregatorBatchReporterAddress =
  "0xbF111982C39b661D1Cbc1621EB1450694Fae1D3f" as const;

interface AggregatorReport {
  rateFeed: string;
  targetAggregator: Address;
  answer: bigint;
  updatedAt: bigint;
}

export async function updateMockAggregators(
  targetChain: ChainName,
  logger: Logger,
  dryRun = false,
): Promise<boolean> {
  const targetAggregatorMappings = aggregatorMappings[targetChain];

  if (!targetAggregatorMappings) {
    logger.error(`No aggregator mappings configured for ${targetChain}`);
    return false;
  }

  if (Object.keys(targetAggregatorMappings).length === 0) {
    logger.error(`Aggregator mapping for ${targetChain} is empty`);
    return false;
  }

  const reports: AggregatorReport[] = [];

  for (const [rateFeed, aggregatorMapping] of Object.entries(
    targetAggregatorMappings,
  )) {
    reports.push(
      await buildAggregatorReport(
        rateFeed,
        getMainnetChain(targetChain),
        aggregatorMapping.mainnet,
        aggregatorMapping.testnet,
      ),
    );
  }

  if (reports.length === 0) {
    logger.error(`No mock aggregator reports generated for ${targetChain}`);
    return false;
  }

  logger.info(
    `Prepared ${reports.length} mock aggregator updates for ${targetChain}`,
  );

  if (dryRun) {
    for (const report of reports) {
      logger.info(
        `${report.rateFeed}: ${report.targetAggregator} answer=${report.answer.toString()} updatedAt=${report.updatedAt.toString()}`,
      );
    }
    return true;
  }

  return await submitBatchReport(targetChain, reports, logger);
}

async function buildAggregatorReport(
  rateFeed: string,
  sourceChain: ChainName,
  sourceAggregator: Address,
  targetAggregator: Address,
): Promise<AggregatorReport> {
  const sourceClient = getPublicClient(sourceChain);

  const [, answer, , updatedAt] = await sourceClient.readContract({
    address: sourceAggregator,
    abi: chainlinkAggregatorAbi,
    functionName: "latestRoundData",
  });

  if (updatedAt === 0n) {
    throw new Error(
      `Source aggregator ${sourceAggregator} for ${rateFeed} on ${sourceChain} returned updatedAt=0`,
    );
  }

  return {
    rateFeed,
    targetAggregator: getAddress(targetAggregator),
    answer,
    updatedAt,
  };
}

async function submitBatchReport(
  targetChain: ChainName,
  reports: AggregatorReport[],
  logger: Logger,
): Promise<boolean> {
  const privateKeySecretId =
    process.env.MOCK_AGGREGATOR_REPORTER_PRIVATE_KEY_SECRET_ID;
  if (!privateKeySecretId) {
    logger.error("MOCK_AGGREGATOR_REPORTER_PRIVATE_KEY_SECRET_ID is not set");
    return false;
  }

  const privateKey = normalizePrivateKey(await getSecret(privateKeySecretId));
  const account = privateKeyToAccount(privateKey);
  const chain = chainMap[targetChain];
  const publicClient = getPublicClient(targetChain);
  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(),
  });

  const contract = getContract({
    address: mockAggregatorBatchReporterAddress,
    abi: mockAggregatorBatchReporterAbi,
    client: { public: publicClient, wallet: walletClient },
  });

  const aggregators = reports.map((report) => report.targetAggregator);
  const answers = reports.map((report) => report.answer);
  const timestamps = reports.map((report) => report.updatedAt);

  const { request } = await contract.simulate.batchReport(
    [aggregators, answers, timestamps],
    { account },
  );
  const hash = await walletClient.writeContract(request);
  const receipt = await publicClient.waitForTransactionReceipt({ hash });

  if (receipt.status !== "success") {
    logger.error(`Mock aggregator batch report tx failed: ${hash}`);
    return false;
  }

  logger.info(`Mock aggregator batch report succeeded: ${hash}`);
  return true;
}

function getPublicClient(chainName: ChainName): PublicClient {
  const existingClient = publicClients.get(chainName);
  if (existingClient) {
    return existingClient;
  }

  const client = createPublicClient({
    chain: chainMap[chainName],
    transport: http(),
  }) as unknown as PublicClient;
  publicClients.set(chainName, client);
  return client;
}

function normalizePrivateKey(privateKey: string): `0x${string}` {
  const trimmedPrivateKey = privateKey.trim();
  return trimmedPrivateKey.startsWith("0x")
    ? (trimmedPrivateKey as `0x${string}`)
    : `0x${trimmedPrivateKey}`;
}

function getMainnetChain(testnetChain: ChainName): ChainName {
  switch (testnetChain) {
    case "celo-sepolia":
      return "celo";
    case "monad-testnet":
      return "monad";
    case "polygon-testnet":
      return "polygon";
    default:
      throw new Error(`No mainnet chain configured for ${testnetChain}`);
  }
}

async function runCli() {
  const targetChain = process.argv[2] as ChainName | undefined;
  const dryRun = process.argv.includes("--dry-run");

  if (!targetChain || !(targetChain in chainMap)) {
    console.error(
      "Usage: npm run update:mocks:<chain> -- [--dry-run]\nSupported chains: celo-sepolia, monad-testnet, polygon-testnet",
    );
    process.exit(1);
  }

  const logger = {
    info: console.log,
    error: console.error,
  } as unknown as Logger;

  const ok = await updateMockAggregators(targetChain, logger, dryRun);
  process.exit(ok ? 0 : 1);
}

if (require.main === module) {
  void runCli();
}
