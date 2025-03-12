import { ContractFunctionRevertedError } from "viem";
import { WebhookClient } from "discord.js";

import config from "./config";
import getSecret from "./get-secret.js";

export async function sendDiscordNotification(
  rateFeedName: string,
  err: ContractFunctionRevertedError,
) {
  const discordWebhookClient = new WebhookClient({
    url: await getSecret(config.DISCORD_WEBHOOK_URL_SECRET_ID),
  });

  await discordWebhookClient.send({
    content: `🚨 Invalid price error while relaying ${rateFeedName}`,
    embeds: [
      {
        title: "Error Details",
        description: JSON.stringify(err),
        color: 0xff0000, // Red color for error
      },
    ],
  });
}

export async function sendTxStuckNotification(
  rateFeedName: string,
  signerAddress: string,
) {
  const discordWebhookClient = new WebhookClient({
    url: await getSecret(config.DISCORD_WEBHOOK_URL_SECRET_ID),
  });

  await discordWebhookClient.send({
    content: `🚨 Tx stuck while relaying prices for ${rateFeedName} from signer address ${signerAddress}, even after retrying with a higher gas price`,
  });
}
