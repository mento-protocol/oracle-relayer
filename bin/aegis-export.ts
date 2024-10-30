import type { Address } from "viem";
import RelayerAddressesJson from "../infra/relayer_addresses.json";
import { config } from "../src/config";
import getSecret from "../src/get-secret";
import { deriveRelayerAccount, toRateFeedId } from "../src/utils";

const RelayerAddresses = RelayerAddressesJson as {
  [env in "staging" | "prod"]: Record<string, Address>;
};

type Environment = keyof typeof RelayerAddresses;
type RateFeed<T extends Environment> = keyof (typeof RelayerAddresses)[T];

interface Relayer {
  env: Environment;
  rateFeedId: Address;
  rateFeed: string;
  relayerAddress: Address;
  signerAddress: Address;
}

async function aegisExport() {
  try {
    const mnemonic = await getSecret(config.RELAYER_MNEMONIC_SECRET_ID);

    const allRelayers = (
      Object.entries(RelayerAddresses) as [
        Environment,
        (typeof RelayerAddresses)[Environment],
      ][]
    ).flatMap(([env, rateFeeds]) =>
      Object.keys(rateFeeds).map((rateFeed) =>
        createRelayer(env, rateFeed, mnemonic),
      ),
    );

    const uniqueRelayers = Array.from(
      new Map(
        allRelayers.map((relayer) => [relayer.rateFeedId, relayer]),
      ).values(),
    );

    const configYaml = generateConfigYaml(uniqueRelayers);

    console.log("\x1b[1m" + configYaml + "\x1b[0m");
  } catch (error) {
    console.error("Error occurred during aegis export:", error);
    process.exit(1);
  }
}

const createRelayer = <T extends Environment>(
  env: T,
  rateFeed: RateFeed<T>,
  mnemonic: string,
): Relayer => {
  // Type assertion (as string) is safe here because we know that the keys of our RelayerAddresses object are always strings
  const formattedRateFeed = (rateFeed as string).replace("_", "").toUpperCase();

  // We use the format {base}/{quote} when deriving the relayer signer address from the rate feed
  const rateFeedWithSlash = (rateFeed as string)
    .replace("_", "/")
    .toUpperCase();

  return {
    env,
    rateFeed: formattedRateFeed,
    rateFeedId: toRateFeedId(`relayed:${formattedRateFeed}`),
    signerAddress: deriveRelayerAccount(mnemonic, rateFeedWithSlash).address,
    relayerAddress: RelayerAddresses[env][rateFeed] as Address,
  };
};

function generateConfigYaml(relayers: Relayer[]): string {
  return `
###############################################################
# Exemplary aegis config.yaml with all relevant values to add #
###############################################################

global:
  vars:
    # Rate Feed IDs
${relayers.map(({ rateFeed, rateFeedId }) => `    'relayed:${rateFeed}': '${rateFeedId}'`).join("\n")}

    # Relayer Signer Wallets
${relayers.map(({ rateFeed, signerAddress }) => `    RelayerSigner${rateFeed}: '${signerAddress}'`).join("\n")}

metrics:
  # Checks for rate feed freshness
  - source: SortedOracles.isOldestReportExpired(address rateFeed)(bool,address)
    schedule: 0/10 * * * * *
    type: gauge
    chains: all
    variants:
${relayers.map(({ rateFeed }) => `      - [relayed:${rateFeed}]`).join("\n")}

  # Checks if the signer wallets have enough CELO to pay for the relay() transactions
  - source: CELOToken.balanceOf(address owner)(uint256)
    schedule: 0/10 * * * * *
    type: gauge
    chains: all
    variants:
${relayers.map(({ rateFeed }) => `      - [RelayerSigner${rateFeed}]`).join("\n")}

################################################################
# Copy/paste the relevant values above into aegis' config.yaml #
################################################################
`;
}

void aegisExport();
