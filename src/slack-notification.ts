import config from "./config";
import getSecret from "./get-secret.js";

/**
 * Posts a message to the #alerts-oracles Slack channel via an incoming
 * webhook (replaces the former per-environment Discord webhooks).
 */
async function sendSlackNotification(text: string) {
  const webhookUrl = await getSecret(config.SLACK_WEBHOOK_URL_SECRET_ID);
  const response = await fetch(webhookUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ text }),
  });

  if (!response.ok) {
    throw new Error(
      `Slack webhook responded with ${String(response.status)}: ${await response.text()}`,
    );
  }
}

export async function sendInvalidPriceNotification(rateFeedName: string) {
  await sendSlackNotification(
    `🚨 [${config.CHAIN}][${rateFeedName}] Chainlink invalid price (<=0) error, please investigate`,
  );
}

export async function sendTxStuckNotification(
  rateFeedName: string,
  signer: string,
) {
  await sendSlackNotification(
    `🚨 [${config.CHAIN}][${rateFeedName}] Relay tx stuck for a 2nd time while relaying prices (sent from ${signer})`,
  );
}
