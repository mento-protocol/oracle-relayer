import { cloudEvent, CloudEvent } from "@google-cloud/functions-framework";
import config from "./config";
import getLogger from "./logger";
import relay from "./relay";
import type { PubsubData, RelayRequested } from "./types";

const isMainnet = config.NODE_ENV !== "development";
const network = isMainnet ? "Celo" : "Alfajores";

cloudEvent("relay", async (event: CloudEvent<PubsubData>) => {
  const eventData = event.data?.message.data;

  if (!eventData) {
    return { status: "error", message: "No event data found" };
  }

  if (typeof eventData !== "string") {
    console.error("Invalid event data format, must be a string:", eventData);
    return { status: "error", message: "Invalid event data format" };
  }

  let parsedEventData: RelayRequested,
    rateFeedName: string,
    relayerAddress: string;
  try {
    const decodedEventData = Buffer.from(eventData, "base64").toString("utf-8");
    parsedEventData = JSON.parse(decodedEventData) as RelayRequested;
    rateFeedName = parsedEventData.rate_feed_name;
    relayerAddress = parsedEventData.relayer_address;
  } catch (error) {
    console.error("Error parsing event data:", eventData, "\n", error);
    return { status: "error", message: "Error parsing event data" };
  }

  if (!relayerAddress) {
    return {
      status: "error",
      message: `Relayer address not found in event data: ${JSON.stringify(parsedEventData, null, 4)}`,
    };
  }

  const logger = getLogger(rateFeedName, network, event.id);
  const ok = await relay(relayerAddress, rateFeedName, logger);
  if (!ok) {
    return { status: "error", message: "Relay failed" };
  }

  return { status: "success" };
});
