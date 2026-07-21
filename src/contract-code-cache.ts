import type { Hex } from "viem";

export async function isContractWithPositiveCache(
  address: string,
  getCode: () => Promise<Hex | undefined>,
  positiveCache: Set<string>,
): Promise<boolean> {
  if (positiveCache.has(address)) {
    return true;
  }

  const code = await getCode();
  const isContract = code !== undefined && code !== "0x";
  if (isContract) {
    positiveCache.add(address);
  }

  return isContract;
}
