import { HDAccount, mnemonicToAccount } from "viem/accounts";

import { createHash } from "crypto";

/**
 * Given a mnemonic and a rate feed name, returns the derived account that will be used
 * for relaying transactions.
 * @param mnemonic The mnemonic to derive the account from
 * @param rateFeedName The name of the rate feed
 * @returns The derived account
 */
export function deriveRelayerAccount(
  mnemonic: string,
  rateFeedName: string,
): HDAccount {
  // Create a deterministic index based on the rate feed
  const hash = createHash("sha256")
    .update(rateFeedName)
    .digest("hex")
    .slice(0, 8);
  // Index must be between 0 and 2^31 - 1 for non-hardened keys (BIP32)
  const accountIndex = parseInt(hash, 16) % 2147483648;

  return mnemonicToAccount(mnemonic, { accountIndex });
}
