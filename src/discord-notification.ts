import { WebhookClient } from "discord.js";

import config from "./config";
import getSecret from "./get-secret.js";

export async function sendInvalidPriceNotification(rateFeedName: string) {
  const discordWebhookClient = new WebhookClient({
    url: await getSecret(config.DISCORD_WEBHOOK_URL_SECRET_ID),
  });

  await discordWebhookClient.send({
    content: `🚨 ${rateFeedName}: Chainlink invalid price (<=0) error, please investigate`,
  });
}

export async function sendTxStuckNotification(
  rateFeedName: string,
  signer: string,
) {
  const discordWebhookClient = new WebhookClient({
    url: await getSecret(config.DISCORD_WEBHOOK_URL_SECRET_ID),
  });

  await discordWebhookClient.send({
    content: `🚨 ${rateFeedName}: Relay tx stuck for a 2nd time while relaying prices (sent from ${signer})`,
  });
}
