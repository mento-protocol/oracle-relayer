import { WebhookClient } from "discord.js";
import config from "./config";
import getSecret from "./get-secret.js";

export default async function sendDiscordNotification(rateFeedName: string) {
  const discordWebhookClient = new WebhookClient({
    url: await getSecret(config.DISCORD_WEBHOOK_URL_SECRET_ID),
  });

  await discordWebhookClient.send(
    `🚨 Invalid price error while relaying ${rateFeedName}`,
  );
}
