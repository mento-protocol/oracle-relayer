import {
  Address,
  BaseError,
  createPublicClient,
  createWalletClient,
  ContractFunctionRevertedError,
  getContract,
  http,
  WalletClient,
} from "viem";
import { celo, celoAlfajores } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";

import config from "./config";
import getLogger from "./logger";
import getSecret from "./get-secret";
import { relayerAbi } from "./relayer-abi";

function getPublicClient() {
  const isMainnet = process.env.NODE_ENV !== "development";
  return createPublicClient({
    chain: isMainnet ? celo : celoAlfajores,
    transport: http(),
  });
}

async function getWalletClient(): Promise<WalletClient> {
  const isMainnet = process.env.NODE_ENV !== "development";
  const pk = await getSecret(config.RELAYER_PK_SECRET_ID);

  return createWalletClient({
    account: privateKeyToAccount(pk as Address),
    chain: isMainnet ? celo : celoAlfajores,
    transport: http(),
  });
}

export default async function relay(
  relayerAddress: string,
  rateFeedName: string,
): Promise<boolean> {
  const logger = getLogger(rateFeedName);
  const publicClient = getPublicClient();
  const wallet = await getWalletClient();

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
      // If the error was a revert from the contract, it should fall into one of two types:
      // 1. A custom error defined in the relayer contract, i.e. InvalidPrice, TimestampNotNew, etc.
      // 2. An error from a require statement, in which case we try to extract the reason
      const errName = revertError.data?.errorName ?? "";
      switch (errName) {
        case "TimestampNotNew": {
          logger.info(
            "Relay not possible. Price from previous relay is still fresh in SortedOracles",
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
          logger.error(
            "Relay failed. Contract reverted with:",
            revertError.reason,
          );
          break;
        }
        default: {
          logger.error(
            `Relay failed. Unknown error type: ${errName} - ${revertError.shortMessage}`,
          );
          break;
        }
      }
      return false;
    }

    // At this point we know that the error is not a revert from the contract, so it could be an error
    // from the rpc client, i.e. not enough balance, incorrect nonce, tx broadcast timeout, etc,. in
    // which case the shortMessage should be descriptive enough
    logger.error(`Relay failed with a non-revert error: ${err.shortMessage}`);

    return false;
  }
}
