import { cloudEvent, CloudEvent } from "@google-cloud/functions-framework";

import relay from "./relay";

interface PubsubData {
  subscription: string;
  message: {
    messageId: string;
    publishTime: string;
    data: string;
    attributes?: Record<string, string>;
  };
}

interface RelayRequested {
  rate_feed_name: string;
  relayer_address: string;
}

cloudEvent("relay", async (event: CloudEvent<PubsubData>) => {
  const eventData = event.data?.message.data;

  if (!eventData) {
    return { status: "error", message: "No event data found" };
  }

  if (typeof eventData !== "string") {
    console.error("Invalid event data format, must be a string:", eventData);
    return { status: "error", message: "Invalid event data format" };
  }

  let parsedEventData, rateFeedName, relayerAddress;
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
    // Return an error response
    return {
      status: "error",
      message: `Relayer address not found in event data: ${JSON.stringify(parsedEventData, null, 4)}`,
    };
  }

  console.log(`Received 'RelayRequested' event for ${rateFeedName}(${relayerAddress})`);

  const ok = await relay(relayerAddress);
  if (!ok) {
    return { status: "error", message: "Relay failed" };
  }

  return { status: "success" };
});
