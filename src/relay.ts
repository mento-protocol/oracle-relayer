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
import config from "./config";
import getSecret from "./get-secret";
import { relayerAbi } from "./relayer-abi";
import { privateKeyToAccount } from "viem/accounts";

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

export default async function relay(relayerAddress: string): Promise<boolean> {
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
      console.log(`Relay tx failed: ${hash}`);
      return false;
    }

    console.log(`Relay tx succeeded: ${hash}`);
    return true;
  } catch (err) {
    if (err instanceof BaseError) {
      const revertError = err.walk(
        (err) => err instanceof ContractFunctionRevertedError,
      );
      if (revertError instanceof ContractFunctionRevertedError) {
        const errName = revertError.data?.errorName ?? "";
        if (errName !== "Error") {
          // One of the custom errors we defined, which should include
          // a more detailed message in the metaMessages field
          const metaMsg = revertError.metaMessages
            ?.map((msg: string) => msg.trim())
            .join("");

          console.log("Contract reverted with error:", metaMsg);
        } else {
          // A generic revert error, which should include the reason
          console.log("Contract reverted with reason:", revertError.reason);
        }
      } else {
        // Non-revert error, for example not enough balance, tx broadcast timeout, etc.
        console.log("Error relaying tx:", err.shortMessage);
      }
    } else {
      console.log("Unknown error relaying tx:", err);
    }

    return false;
  }
}