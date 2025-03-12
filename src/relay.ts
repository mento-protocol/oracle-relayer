import type {
  Address,
  GetContractReturnType,
  PublicClient,
  WalletClient,
} from "viem";
import {
  BaseError,
  ContractFunctionRevertedError,
  createPublicClient,
  createWalletClient,
  getContract,
  http,
  parseGwei,
} from "viem";
import { celo, celoAlfajores } from "viem/chains";

import type { Logger } from "winston";
import config from "./config";
import {
  sendDiscordNotification,
  sendTxStuckNotification,
} from "./send-discord-notification";
import getSecret from "./get-secret";
import { relayerAbi } from "./relayer-abi";
import { deriveRelayerAccount } from "./utils";

const isMainnet = config.NODE_ENV !== "development";

// Re-use clients across function invocations to save on initialization time and memory
let publicClient: PublicClient;
const walletClients: Map<string, WalletClient> = new Map<
  string,
  WalletClient
>();
const contractCodeCache = new Map<string, boolean>();

type RelayerContract = GetContractReturnType<typeof relayerAbi, PublicClient>;

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
    return await submitTx(contract, isRetryAttempt, logger);
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
      chain: isMainnet ? celo : celoAlfajores,
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
      chain: isMainnet ? celo : celoAlfajores,
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
  isRetryAttempt: boolean,
  logger: Logger,
): Promise<boolean> {
  await relayerContract.simulate.relay();

  const baseGasFee = parseGwei("25");
  // Attempt to use 2x the base gas fee if it's a retry attempt, otherwise let the RPC decide
  const params = isRetryAttempt
    ? { maxFeePerGas: baseGasFee * 2n, maxPriorityFeePerGas: baseGasFee * 2n }
    : {};

  // @ts-expect-error todo: tricky to get the params recognized when using the type from the abi
  const hash = await relayerContract.write.relay(params);
  const receipt = await publicClient.waitForTransactionReceipt({
    hash,
    timeout: 50 * 1000, // 10 (L1) or 50 (L2) blocks for the tx to be mined
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
  rateFeedName: string,
  revertError: ContractFunctionRevertedError,
  logger: Logger,
) {
  const errName = revertError.data?.errorName ?? "";
  switch (errName) {
    case "TimestampNotNew": {
      logger.info(
        "Relay skipped. Price from previous relay is still fresh in SortedOracles",
      );
      break;
    }
    case "ExpiredTimestamp": {
      logger.warn(
        "Relay not possible. The current price is too old to be relayed",
      );
      break;
    }
    case "InvalidPrice": {
      logger.error("Relay failed. Chainlink price is invalid");
      await sendDiscordNotification(rateFeedName, revertError);
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
