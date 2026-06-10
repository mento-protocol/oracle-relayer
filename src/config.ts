import { JSONSchemaType, envSchema } from "env-schema";

export interface Env {
  SLACK_WEBHOOK_URL_SECRET_ID: string;
  GCP_PROJECT_ID: string;
  NODE_ENV: string;
  RELAYER_MNEMONIC_SECRET_ID: string;
  // Optional Secret Manager secret ID holding the primary RPC URL (e.g. a
  // dedicated QuickNode endpoint). When unset, the chain's default public RPC
  // is used. See initTransport() in relay.ts.
  RPC_URL_SECRET_ID?: string;
  CHAIN:
    | "celo"
    | "celo-sepolia"
    | "monad-testnet"
    | "monad"
    | "polygon-testnet";
}

const schema: JSONSchemaType<Env> = {
  type: "object",
  required: [
    "SLACK_WEBHOOK_URL_SECRET_ID",
    "GCP_PROJECT_ID",
    "NODE_ENV",
    "RELAYER_MNEMONIC_SECRET_ID",
    "CHAIN",
  ],
  properties: {
    SLACK_WEBHOOK_URL_SECRET_ID: { type: "string" },
    GCP_PROJECT_ID: { type: "string" },
    NODE_ENV: { type: "string" },
    RELAYER_MNEMONIC_SECRET_ID: { type: "string" },
    RPC_URL_SECRET_ID: { type: "string", nullable: true },
    CHAIN: {
      type: "string",
      enum: [
        "celo",
        "celo-sepolia",
        "monad-testnet",
        "monad",
        "polygon-testnet",
      ],
    },
  },
};

export const config = envSchema({
  schema,
  dotenv: true, // load .env if it is there
});

export default config;
