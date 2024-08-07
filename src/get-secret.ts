import { SecretManagerServiceClient } from "@google-cloud/secret-manager";
import config from "./config.js";

/**
 * Load a secret from Secret Manager
 */
export default async function getSecret(secretId: string): Promise<string> {
  try {
    const secretManager = new SecretManagerServiceClient();
    const secretFullResourceName = `projects/${config.GCP_PROJECT_ID}/secrets/${secretId}/versions/latest`;
    const [version] = await secretManager.accessSecretVersion({
      name: secretFullResourceName,
    });

    const secret = version.payload?.data?.toString();

    if (!secret) {
      throw new Error(
        `Secret '${secretId}' is empty or undefined. Please check the secret in Secret Manager.`,
      );
    }

    return secret;
  } catch (error) {
    console.error(
      `Failed to retrieve secret '${secretId}' from secret manager:`,
      error,
    );
    throw error;
  }
}
