import { cloudEvent, CloudEvent } from "@google-cloud/functions-framework";
import config from "./config";
import getSecret from "./get-secret";
import getLogger from "./logger";
import { refillRelayers } from "./refill-relayers";
import relay from "./relay";
import type { PubsubData, RefillRequested, RelayRequested } from "./types";
import { updateMockAggregators } from "./update-mock-aggregators";
import { getTraceId } from "./utils";

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

  const traceId = getTraceId(event);
  const logger = getLogger(rateFeedName, traceId);
  const ok = await relay(relayerAddress, rateFeedName, logger);

  if (!ok) {
    return { status: "error", message: "Relay failed" };
  }

  return { status: "success" };
});

cloudEvent("updateMockAggregators", async (event: CloudEvent<PubsubData>) => {
  const traceId = getTraceId(event);
  const logger = getLogger("mock-aggregator-updater", traceId);

  let ok: boolean;
  try {
    ok = await updateMockAggregators(config.CHAIN, logger);
  } catch (error) {
    logger.error(
      "Mock aggregator update failed with an unhandled error",
      error,
    );
    return { status: "error", message: "Mock aggregator update failed" };
  }

  if (!ok) {
    return { status: "error", message: "Mock aggregator update failed" };
  }

  return { status: "success" };
});

// Runs once a day per chain (see infra/scheduler.tf) and tops up every relayer
// signer that is below its runway threshold from the refiller wallet. Same
// logic as `npm run refill:<chain>`. Logs a single "Refill ok" / "Refill
// failed" line per run.
cloudEvent("refillRelayers", async (event: CloudEvent<PubsubData>) => {
  const traceId = getTraceId(event);
  const logger = getLogger("refill-relayers", traceId);

  try {
    const eventData = event.data?.message.data;
    if (typeof eventData !== "string") {
      throw new Error("No event data found");
    }
    const { rate_feeds: rateFeedKeys } = JSON.parse(
      Buffer.from(eventData, "base64").toString("utf-8"),
    ) as RefillRequested;
    if (!Array.isArray(rateFeedKeys) || rateFeedKeys.length === 0) {
      throw new Error("Event data contains no rate_feeds");
    }

    if (!config.REFILLER_PRIVATE_KEY_SECRET_ID) {
      throw new Error("REFILLER_PRIVATE_KEY_SECRET_ID is not set");
    }
    const [mnemonic, refillerPrivateKey] = await Promise.all([
      getSecret(config.RELAYER_MNEMONIC_SECRET_ID),
      getSecret(config.REFILLER_PRIVATE_KEY_SECRET_ID),
    ]);

    const dryRun = process.env.REFILL_DRY_RUN === "true";
    const result = await refillRelayers(
      config.CHAIN,
      rateFeedKeys,
      mnemonic,
      refillerPrivateKey,
      dryRun,
    );

    const { symbol } = result;
    const totalSent = result.transfers.reduce((sum, t) => sum + t.amount, 0);
    const counts = `${result.transfers.length.toString()} of ${result.rows.length.toString()} relayers`;
    const refiller = `refiller ${result.refillerAddress} has ${result.refillerBalanceAfter.toFixed(2)} ${symbol}`;
    const summary = dryRun
      ? `[dry run] would top up ${counts} with ${totalSent.toString()} ${symbol}, nothing was sent, ${refiller}`
      : `${counts} topped up, ${totalSent.toString()} ${symbol} sent, ${refiller} left`;
    const details = {
      transfers: result.transfers,
      errors: result.errors,
    };

    if (result.errors.length > 0) {
      logger.error(
        `Refill failed: ${result.errors.length.toString()} transfers could not be sent. ${summary}`,
        details,
      );
      return { status: "error", message: "Refill failed" };
    }

    logger.info(`Refill ok: ${summary}`, details);
    return { status: "success" };
  } catch (error) {
    logger.error("Refill failed with an unhandled error", error);
    return { status: "error", message: "Refill failed" };
  }
});
