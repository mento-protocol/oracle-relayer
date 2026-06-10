import config from "./config";
import getSecret from "./get-secret.js";

/**
 * Posts a message to Slack via `chat.postMessage`, authenticated with the
 * shared Mento alerts bot token (the same Slack app the monitoring
 * monorepo's Grafana contact points use). The bot's `chat:write.public`
 * scope lets it post to public channels by name without being a member.
 *
 * Note: the Slack Web API signals failure with HTTP 200 + `ok: false`,
 * so the response body must be checked, not just the HTTP status.
 */
async function sendSlackNotification(text: string) {
  const botToken = await getSecret(config.SLACK_BOT_TOKEN_SECRET_ID);
  const response = await fetch("https://slack.com/api/chat.postMessage", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${botToken}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify({ channel: config.SLACK_CHANNEL, text }),
  });

  const body = (await response.json()) as { ok?: boolean; error?: string };
  if (!response.ok || body.ok !== true) {
    throw new Error(
      `Slack chat.postMessage failed with status ${String(response.status)}: ${body.error ?? "unknown"}`,
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
