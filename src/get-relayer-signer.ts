import { Account } from "viem";

import { config } from "./config";
import { deriveRelayerAccount } from "./utils";
import getSecret from "./get-secret";

async function main() {
  if (process.argv.length < 3) {
    console.log("Usage: npm run get:relayer:signer -- <ratefeed>");
    console.log("e.g. npm run get:relayer:signer -- PHP/USD");
    process.exit(1);
  }

  const ratefeed = process.argv[2];

  try {
    const mnemonic = await getSecret(config.RELAYER_MNEMONIC_SECRET_ID);
    const account: Account = deriveRelayerAccount(mnemonic, ratefeed);
    console.log(`Derived address for ${ratefeed}: ${account.address}`);
  } catch (error) {
    console.error("Error deriving account:", error);
    process.exit(1);
  }
}

void main();
