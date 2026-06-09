import type {
  Address,
  Chain,
  GetContractReturnType,
  PublicClient,
  WalletClient,
} from "viem";
import {
  BaseError,
  ContractFunctionRevertedError,
  createPublicClient,
  createWalletClient,
  encodeFunctionData,
  getContract,
  http,
} from "viem";
import {
  celo,
  celoSepolia,
  monad,
  monadTestnet,
  polygonAmoy,
} from "viem/chains";

import type { Logger } from "winston";
import { chainlinkAggregatorAbi } from "./chainlink-aggregator-abi";
import config from "./config";
import {
  sendInvalidPriceNotification,
  sendTxStuckNotification,
} from "./discord-notification";
import getSecret from "./get-secret";
import { relayerAbi } from "./relayer-abi";
import { deriveRelayerAccount } from "./utils";

const chainMap: Record<typeof config.CHAIN, Chain> = {
  celo: celo,
  "celo-sepolia": celoSepolia,
  "monad-testnet": monadTestnet,
  monad: monad,
  "polygon-testnet": polygonAmoy,
};

// Re-use clients across function invocations to save on initialization time and memory
let publicClient: PublicClient;
const walletClients: Map<string, WalletClient> = new Map<
  string,
  WalletClient
>();
const contractCodeCache = new Map<string, boolean>();

type RelayerContract = GetContractReturnType<typeof relayerAbi, PublicClient>;

const sortedOraclesAbi = [
  {
    type: "function",
    name: "medianTimestamp",
    inputs: [{ name: "rateFeedId", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getTokenReportExpirySeconds",
    inputs: [{ name: "rateFeedId", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
] as const;

interface AggregatorDiagnostic {
  aggregator: Address;
  invert: boolean;
  latestRoundId: string;
  latestUpdatedAt: string;
  latestUpdatedAtIso: string;
  latestUpdatedAtAgeSeconds: string;
}

interface RelayDiagnostic {
  checkedAt: string;
  checkedAtIso: string;
  rateFeedId: Address;
  sortedOracles: Address;
  sortedOraclesMedianTimestamp: string;
  sortedOraclesMedianTimestampIso: string;
  sortedOraclesMedianTimestampAgeSeconds: string;
  sortedOraclesReportExpirySeconds: string;
  chainlinkAggregators: AggregatorDiagnostic[];
  newestChainlinkUpdatedAt: string;
  newestChainlinkUpdatedAtIso: string;
  newestChainlinkUpdatedAtAgeSeconds: string;
  oldestChainlinkUpdatedAt: string;
  oldestChainlinkUpdatedAtIso: string;
  oldestChainlinkUpdatedAtAgeSeconds: string;
  chainlinkNewestLagVsSortedOraclesMedianSeconds: string;
  timestampSpreadSeconds: string;
  maxTimestampSpreadSeconds: string;
}

interface ChainlinkAggregatorConfig {
  aggregator: Address;
  invert: boolean;
}

export default async function relay(
  relayerAddress: string,
  rateFeedName: string,
  logger: Logger,
  isRetryAttempt = false,
): Promise<boolean> {
  logger.info(`Relay request received for ${relayerAddress}`);

  if (!(await isContract(relayerAddress))) {
    logger.error(
      `Relay failed. Relayer address ${relayerAddress} is not a contract.`,
    );
    return false;
  }

  const publicClient = getOrCreatePublicClient();
  const wallet = await getOrCreateWalletClient(rateFeedName);

  const contract: RelayerContract = getContract({
    address: relayerAddress as Address,
    abi: relayerAbi,
    client: { public: publicClient, wallet },
  });

  try {
    return await submitTx(
      contract,
      publicClient,
      wallet,
      isRetryAttempt,
      logger,
    );
  } catch (err) {
    if (!(err instanceof BaseError)) {
      // Theoretically should never happen, as all errors in Viem should extend BaseError
      logger.error("Relay failed due to an unknown non-BaseError:", err);
      return false;
    }

    const revertError = err.walk(
      (err) => err instanceof ContractFunctionRevertedError,
    );
    if (revertError instanceof ContractFunctionRevertedError) {
      await handleContractFunctionRevertError(
        contract,
        publicClient,
        rateFeedName,
        revertError,
        logger,
      );
      return false;
    }

    // At this point we know that the error is not a revert from the contract, so it could be an error
    // from the rpc client, i.e. not enough balance, incorrect nonce, tx broadcast timeout, etc,. in
    // which case the shortMessage should be descriptive enough
    const signerAddress =
      (wallet.account?.address as string | undefined) ?? "<undefined>";
    return await handleNonRevertError(
      relayerAddress,
      rateFeedName,
      signerAddress,
      isRetryAttempt,
      err,
      logger,
    );
  }
}

/**
 * Either returns an existing cached public client or creates a new one if it doesn't exist
 */
function getOrCreatePublicClient(): PublicClient {
  // This value is NOT always falsy, as it is set in the first call to this function and will be true in subsequent calls
  // eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
  if (!publicClient) {
    publicClient = createPublicClient({
      chain: chainMap[config.CHAIN],
      transport: http(),
      // NOTE: viem's typescript support is super annoying, couldn't figure out how to make this work without the cast
    }) as unknown as PublicClient;
  }
  return publicClient;
}

/**
 * Either returns an existing cached wallet client or creates a new one if it doesn't exist
 */
async function getOrCreateWalletClient(
  rateFeedName: string,
): Promise<WalletClient> {
  if (!walletClients.has(rateFeedName)) {
    const mnemonic = await getSecret(config.RELAYER_MNEMONIC_SECRET_ID);
    const newWalletClient = createWalletClient({
      account: deriveRelayerAccount(mnemonic, rateFeedName),
      chain: chainMap[config.CHAIN],
      transport: http(),
    });
    walletClients.set(rateFeedName, newWalletClient);
  }

  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  return walletClients.get(rateFeedName)!;
}

async function isContract(address: string): Promise<boolean> {
  if (contractCodeCache.has(address)) {
    return contractCodeCache.get(address) ?? false;
  }

  const publicClient = getOrCreatePublicClient();
  const contractCode = await publicClient.getCode({
    address: address as Address,
  });

  // Viem's getCode transforms the "0x" returned by the raw eth_getCode RPC call to undefined automatically:
  // https://github.com/wevm/viem/blob/5f6009360eaa41caf7318deb832dae7484190b5b/src/actions/public/getCode.ts#L71
  const isContract = !!contractCode;
  contractCodeCache.set(address, isContract);
  return isContract;
}

async function submitTx(
  relayerContract: RelayerContract,
  client: PublicClient,
  wallet: WalletClient,
  isRetryAttempt: boolean,
  logger: Logger,
): Promise<boolean> {
  await relayerContract.simulate.relay();

  const gasParams = await client.estimateFeesPerGas();
  if (isRetryAttempt) {
    // We only re-attempt txs that got stuck in the mempool, so we use 2x the recommended gas in case
    // that was the issue
    gasParams.maxFeePerGas *= 2n;
    gasParams.maxPriorityFeePerGas *= 2n;
  }

  // eth_estimateGas returns the exact gas needed at the current state, but by the time the tx is
  // mined, the state may have changed (e.g. different position in SortedOracles linked list),
  // causing slightly higher gas usage. Adding a buffer prevents out-of-gas failures.
  const gasEstimate = await client.estimateGas({
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    account: wallet.account!,
    to: relayerContract.address,
    data: encodeFunctionData({ abi: relayerAbi, functionName: "relay" }),
  });
  const gas = (gasEstimate * 105n) / 100n;

  const hash = await relayerContract.write.relay([], { ...gasParams, gas });
  const receipt = await publicClient.waitForTransactionReceipt({
    hash,
  });

  if (receipt.status !== "success") {
    logger.error(`Relay tx failed: ${hash}`);
    return false;
  }

  logger.info(`Relay succeeded: ${hash}`);
  return true;
}

/**
 * If the error was a revert from the contract, it should fall into one of two types:
 *   1. A custom error defined in the relayer contract, i.e. InvalidPrice, TimestampNotNew, etc.
 *   2. An error from a require statement, in which case we try to extract the reason
 */
async function handleContractFunctionRevertError(
  relayerContract: RelayerContract,
  client: PublicClient,
  rateFeedName: string,
  revertError: ContractFunctionRevertedError,
  logger: Logger,
) {
  const errName = revertError.data?.errorName ?? "";
  switch (errName) {
    case "TimestampNotNew": {
      const diagnostic = await getRelayDiagnostic(relayerContract, client);
      logger.info(
        "Relay skipped. Chainlink timestamp is not newer than SortedOracles median timestamp",
        diagnostic ?? undefined,
      );
      break;
    }
    case "ExpiredTimestamp": {
      const diagnostic = await getRelayDiagnostic(relayerContract, client);
      logger.warn(
        "Relay not possible. The current price is too old to be relayed",
        diagnostic ?? undefined,
      );
      break;
    }
    case "TimestampSpreadTooHigh": {
      const diagnostic = await getRelayDiagnostic(relayerContract, client);
      logger.warn(
        "Relay not possible. Chainlink aggregator timestamps differ by more than maxTimestampSpread",
        diagnostic ?? undefined,
      );
      break;
    }
    case "InvalidPrice": {
      logger.error("Relay failed. Chainlink price is invalid");
      logger.error(JSON.stringify(revertError, null, 2));
      await sendInvalidPriceNotification(rateFeedName);
      break;
    }
    case "Error": {
      logger.error("Relay failed. Contract reverted with:", revertError.reason);
      break;
    }
    default: {
      logger.error(
        `Relay failed. Unknown error type: ${errName} - ${revertError.shortMessage}`,
      );
      break;
    }
  }
}

async function getRelayDiagnostic(
  relayerContract: RelayerContract,
  client: PublicClient,
): Promise<RelayDiagnostic | undefined> {
  try {
    const checkedAt = BigInt(Math.floor(Date.now() / 1000));
    const [
      rawRateFeedId,
      rawSortedOracles,
      rawMaxTimestampSpread,
      rawAggregators,
    ] = await Promise.all([
      relayerContract.read.rateFeedId(),
      relayerContract.read.sortedOracles(),
      relayerContract.read.maxTimestampSpread(),
      relayerContract.read.getAggregators(),
    ]);
    const rateFeedId = rawRateFeedId as Address;
    const sortedOracles = rawSortedOracles as Address;
    const maxTimestampSpread = rawMaxTimestampSpread as bigint;
    const aggregators = rawAggregators as ChainlinkAggregatorConfig[];

    const [medianTimestamp, reportExpirySeconds, aggregatorRounds] =
      await Promise.all([
        client.readContract({
          address: sortedOracles,
          abi: sortedOraclesAbi,
          functionName: "medianTimestamp",
          args: [rateFeedId],
        }),
        client.readContract({
          address: sortedOracles,
          abi: sortedOraclesAbi,
          functionName: "getTokenReportExpirySeconds",
          args: [rateFeedId],
        }),
        Promise.all(
          aggregators.map(async ({ aggregator, invert }) => {
            const [roundId, , , updatedAt] = await client.readContract({
              address: aggregator,
              abi: chainlinkAggregatorAbi,
              functionName: "latestRoundData",
            });

            return {
              aggregator,
              invert,
              latestRoundId: roundId.toString(),
              latestUpdatedAt: updatedAt.toString(),
              latestUpdatedAtIso: formatUnixTimestamp(updatedAt),
              latestUpdatedAtAgeSeconds: secondsSince(
                checkedAt,
                updatedAt,
              ).toString(),
            };
          }),
        ),
      ]);

    const updatedAts: bigint[] = aggregatorRounds.map(({ latestUpdatedAt }) =>
      BigInt(latestUpdatedAt),
    );
    const oldestChainlinkUpdatedAt = updatedAts.reduce(
      (oldest, updatedAt) =>
        oldest === 0n || updatedAt < oldest ? updatedAt : oldest,
      0n,
    );
    const newestChainlinkUpdatedAt = updatedAts.reduce(
      (newest, updatedAt) => (updatedAt > newest ? updatedAt : newest),
      0n,
    );

    return {
      checkedAt: checkedAt.toString(),
      checkedAtIso: formatUnixTimestamp(checkedAt),
      rateFeedId,
      sortedOracles,
      sortedOraclesMedianTimestamp: medianTimestamp.toString(),
      sortedOraclesMedianTimestampIso: formatUnixTimestamp(medianTimestamp),
      sortedOraclesMedianTimestampAgeSeconds: secondsSince(
        checkedAt,
        medianTimestamp,
      ).toString(),
      sortedOraclesReportExpirySeconds: reportExpirySeconds.toString(),
      chainlinkAggregators: aggregatorRounds,
      newestChainlinkUpdatedAt: newestChainlinkUpdatedAt.toString(),
      newestChainlinkUpdatedAtIso: formatUnixTimestamp(
        newestChainlinkUpdatedAt,
      ),
      newestChainlinkUpdatedAtAgeSeconds: secondsSince(
        checkedAt,
        newestChainlinkUpdatedAt,
      ).toString(),
      oldestChainlinkUpdatedAt: oldestChainlinkUpdatedAt.toString(),
      oldestChainlinkUpdatedAtIso: formatUnixTimestamp(
        oldestChainlinkUpdatedAt,
      ),
      oldestChainlinkUpdatedAtAgeSeconds: secondsSince(
        checkedAt,
        oldestChainlinkUpdatedAt,
      ).toString(),
      chainlinkNewestLagVsSortedOraclesMedianSeconds: positiveDiff(
        medianTimestamp,
        newestChainlinkUpdatedAt,
      ).toString(),
      timestampSpreadSeconds: (
        newestChainlinkUpdatedAt - oldestChainlinkUpdatedAt
      ).toString(),
      maxTimestampSpreadSeconds: maxTimestampSpread.toString(),
    };
  } catch {
    return undefined;
  }
}

function formatUnixTimestamp(timestamp: bigint): string {
  if (timestamp === 0n) {
    return "never";
  }

  return new Date(Number(timestamp) * 1000).toISOString();
}

function secondsSince(now: bigint, timestamp: bigint): bigint {
  return positiveDiff(now, timestamp);
}

function positiveDiff(left: bigint, right: bigint): bigint {
  return left > right ? left - right : 0n;
}

async function handleNonRevertError(
  relayerAddress: string,
  rateFeedName: string,
  signerAddress: string,
  isRetryAttempt: boolean,
  err: BaseError,
  logger: Logger,
): Promise<boolean> {
  switch (err.details) {
    case "insufficient funds for transfer":
      logger.error(
        `Relay failed. Looks like the signer address ${signerAddress} doesnt have enough funds for the tx`,
      );
      return false;
    case "replacement transaction underpriced":
      // Sometimes a tx is broadcasted but not mined and gets stuck in the mempool. In this case, we attempt
      // a single second relay with a higher gas price to replace the old tx.

      if (isRetryAttempt) {
        // Already retried once and it didnt work
        logger.error(
          `Relay failed. Tx from signer ${signerAddress} remains stuck in the mempool after retrying. Will not retry again.`,
        );
        await sendTxStuckNotification(rateFeedName, signerAddress);
        return false;
      }

      logger.info(
        `Relay failed. Looks like a tx from signer ${signerAddress} is stuck in the mempool, will retry once with a higher gas price`,
      );
      return await relay(relayerAddress, rateFeedName, logger, true);
    default:
      logger.error(
        `Relay failed with an unknown non-revert error: ${err.shortMessage}`,
      );
      logger.error(JSON.stringify(err, null, 2));
      return false;
  }
}
