import { JSONSchemaType, envSchema } from "env-schema";

export interface Env {
  DISCORD_WEBHOOK_URL_SECRET_ID: string;
  GCP_PROJECT_ID: string;
  NODE_ENV: string;
  RELAYER_MNEMONIC_SECRET_ID: string;
  REFILLER_PRIVATE_KEY?: string;
}

const schema: JSONSchemaType<Env> = {
  type: "object",
  required: [
    "DISCORD_WEBHOOK_URL_SECRET_ID",
    "GCP_PROJECT_ID",
    "NODE_ENV",
    "RELAYER_MNEMONIC_SECRET_ID",
  ],
  properties: {
    DISCORD_WEBHOOK_URL_SECRET_ID: { type: "string" },
    GCP_PROJECT_ID: { type: "string" },
    NODE_ENV: { type: "string" },
    RELAYER_MNEMONIC_SECRET_ID: { type: "string" },
    REFILLER_PRIVATE_KEY: { type: "string", nullable: true },
  },
};

export const config = envSchema({
  schema,
  dotenv: true, // load .env if it is there
});

export default config;
