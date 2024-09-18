import { Address, getAddress, keccak256, toHex } from "viem";
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
  // See https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki#extended-keys
  const accountIndex = parseInt(hash, 16) % 2 ** 31;

  return mnemonicToAccount(mnemonic, { accountIndex });
}

/**
 * A JavaScript implementation of our rateFeed ID generation algorithm.
 * Original solidity code is: address(uint160(uint256(keccak256(abi.encodePacked(rateFeed)))))
}
 * @param rateFeed The rate feed name in string format, i.e. "PHPUSD" or "CELOPHP"
 * @returns The rate feed ID in address format, i.e. "0xab921d6ab1057601A9ae19879b111fC381a2a8E9" for PHPUSD
 */
export function toRateFeedId(rateFeed: string): Address {
  // 1. Calculate keccak256 hash
  const hashedBytes = keccak256(toHex(rateFeed));

  // 2. Convert to BigInt (equivalent to uint256)
  const hashAsBigInt = BigInt(hashedBytes);

  // 3. Mask to 160 bits (equivalent to uint160)
  const maskedToUint160 = hashAsBigInt & ((1n << 160n) - 1n);

  // 4. Convert to address (hex string)
  const addressHex = "0x" + maskedToUint160.toString(16).padStart(40, "0");

  // 5. Return calculated rate feed ID
  return getAddress(addressHex);
}
