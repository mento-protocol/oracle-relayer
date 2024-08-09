import { JSONSchemaType, envSchema } from "env-schema";

export interface Env {
  GCP_PROJECT_ID: string;
  RELAYER_PK_SECRET_ID: string;
}

const schema: JSONSchemaType<Env> = {
  type: "object",
  required: ["GCP_PROJECT_ID", "RELAYER_PK_SECRET_ID"],
  properties: {
    GCP_PROJECT_ID: { type: "string" },
    RELAYER_PK_SECRET_ID: { type: "string" },
  },
};

export const config = envSchema({
  schema,
  dotenv: true, // load .env if it is there
});

export default config;
