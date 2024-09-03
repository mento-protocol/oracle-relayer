import { JSONSchemaType, envSchema } from "env-schema";

export interface Env {
  GCP_PROJECT_ID: string;
  NODE_ENV: string;
  RELAYER_MNEMONIC_SECRET_ID: string;
  DISCORD_WEBHOOK_URL_SECRET_ID: string;
}

const schema: JSONSchemaType<Env> = {
  type: "object",
  required: [
    "GCP_PROJECT_ID",
    "NODE_ENV",
    "DISCORD_WEBHOOK_URL_SECRET_ID",
    "RELAYER_MNEMONIC_SECRET_ID",
  ],
  properties: {
    GCP_PROJECT_ID: { type: "string" },
    DISCORD_WEBHOOK_URL_SECRET_ID: { type: "string" },
    NODE_ENV: { type: "string" },
    RELAYER_MNEMONIC_SECRET_ID: { type: "string" },
  },
};

export const config = envSchema({
  schema,
  dotenv: true, // load .env if it is there
});

export default config;
