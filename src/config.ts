import { JSONSchemaType, envSchema } from "env-schema";

export interface Env {
  SLACK_BOT_TOKEN_SECRET_ID: string;
  // Channel the app-level alerts post to, e.g. "#alerts-oracles". Set per
  // workspace by terraform (see local.slack_channel in infra/main.tf).
  SLACK_CHANNEL: string;
  GCP_PROJECT_ID: string;
  NODE_ENV: string;
  RELAYER_MNEMONIC_SECRET_ID: string;
  // Optional Secret Manager secret ID holding the primary RPC URL (e.g. a
  // dedicated QuickNode endpoint). When unset, the chain's default public RPC
  // is used. See initTransport() in relay.ts.
  RPC_URL_SECRET_ID?: string;
  // Secret Manager secret ID holding the private key of the refiller wallet,
  // which tops up the relayer signers. Set on the refillRelayers cloud
  // functions and in the local .env (for `npm run refill:<chain>`).
  REFILLER_PRIVATE_KEY_SECRET_ID?: string;
  // Local only, optional: overrides the Secret Manager key for
  // `npm run refill:<chain>`. Declared here because env-schema (v8+) no longer
  // copies .env into process.env, it only returns variables in this schema.
  REFILLER_PRIVATE_KEY?: string;
  CHAIN:
    | "celo"
    | "celo-sepolia"
    | "monad-testnet"
    | "monad"
    | "polygon-testnet"
    | "polygon";
}

const schema: JSONSchemaType<Env> = {
  type: "object",
  required: [
    "SLACK_BOT_TOKEN_SECRET_ID",
    "SLACK_CHANNEL",
    "GCP_PROJECT_ID",
    "NODE_ENV",
    "RELAYER_MNEMONIC_SECRET_ID",
    "CHAIN",
  ],
  properties: {
    SLACK_BOT_TOKEN_SECRET_ID: { type: "string" },
    SLACK_CHANNEL: { type: "string" },
    GCP_PROJECT_ID: { type: "string" },
    NODE_ENV: { type: "string" },
    RELAYER_MNEMONIC_SECRET_ID: { type: "string" },
    RPC_URL_SECRET_ID: { type: "string", nullable: true },
    REFILLER_PRIVATE_KEY_SECRET_ID: { type: "string", nullable: true },
    REFILLER_PRIVATE_KEY: { type: "string", nullable: true },
    CHAIN: {
      type: "string",
      enum: [
        "celo",
        "celo-sepolia",
        "monad-testnet",
        "monad",
        "polygon-testnet",
        "polygon",
      ],
    },
  },
};

export const config = envSchema({
  schema,
  dotenv: true, // load .env if it is there
});

export default config;
