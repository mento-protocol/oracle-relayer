import { Account } from "viem";

import { config } from "./config";
import { deriveRelayerAccount } from "./utils";
import getSecret from "./get-secret";

async function main() {
  if (process.argv.length < 3) {
    console.log(
      "Usage: npm run get:relayer:signer -- <ratefeed1> <ratefeed2> ...",
    );
    console.log("e.g. npm run get:relayer:signer -- CELO/PHP PHP/USD");
    process.exit(1);
  }

  const ratefeeds = process.argv.slice(2);

  try {
    const mnemonic = await getSecret(config.RELAYER_MNEMONIC_SECRET_ID);
    for (const ratefeed of ratefeeds) {
      const account: Account = deriveRelayerAccount(mnemonic, ratefeed);
      console.log(`${ratefeed}: ${account.address}`);
    }
  } catch (error) {
    console.error("Error deriving relayer signer account:", error);
    process.exit(1);
  }
}

void main();
