import type { Address, PublicClient, WalletClient } from "viem";
import {
  BaseError,
  ContractFunctionRevertedError,
  createPublicClient,
  createWalletClient,
  getContract,
  http,
} from "viem";
import { celo, celoAlfajores } from "viem/chains";

import config from "./config";
import { deriveRelayerAccount } from "./utils";
import getSecret from "./get-secret";
import getLogger from "./logger";
import { relayerAbi } from "./relayer-abi";

const isMainnet = config.NODE_ENV !== "development";

// Re-use clients across function invocations to save on initialization time and memory
let publicClient: PublicClient;
const walletClients: Map<string, WalletClient> = new Map<
  string,
  WalletClient
>();
const contractCodeCache = new Map<string, boolean>();

export default async function relay(
  relayerAddress: string,
  rateFeedName: string,
  network: string,
): Promise<boolean> {
  const logger = getLogger(rateFeedName, network);
  logger.info(`Relay request received for ${relayerAddress}`);

  if (!(await isContract(relayerAddress))) {
    logger.error(
      `Relay failed. Relayer address ${relayerAddress} is not a contract.`,
    );
    return false;
  }

  const publicClient = getOrCreatePublicClient();
  const wallet = await getOrCreateWalletClient(rateFeedName);

  const contract = getContract({
    address: relayerAddress as Address,
    abi: relayerAbi,
    client: { public: publicClient, wallet },
  });

  try {
    await contract.simulate.relay();

    const hash = await contract.write.relay();
    const receipt = await publicClient.waitForTransactionReceipt({
      hash,
      timeout: 50 * 1000, // 10 blocks for the tx to be mined
    });

    if (receipt.status !== "success") {
      logger.error(`Relay tx failed: ${hash}`);
      return false;
    }

    logger.info(`Relay succeeded: ${hash}`);
    return true;
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
      handleContractFunctionRevertError(revertError, logger);
      return false;
    }

    // At this point we know that the error is not a revert from the contract, so it could be an error
    // from the rpc client, i.e. not enough balance, incorrect nonce, tx broadcast timeout, etc,. in
    // which case the shortMessage should be descriptive enough
    logger.error(`Relay failed with a non-revert error: ${err.shortMessage}`);

    return false;
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

/**
 * If the error was a revert from the contract, it should fall into one of two types:
 *   1. A custom error defined in the relayer contract, i.e. InvalidPrice, TimestampNotNew, etc.
 *   2. An error from a require statement, in which case we try to extract the reason
 */
function handleContractFunctionRevertError(
  revertError: ContractFunctionRevertedError,
  logger: ReturnType<typeof getLogger>,
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
