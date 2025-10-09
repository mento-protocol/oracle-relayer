import { LoggingWinston } from "@google-cloud/logging-winston";
import winston, { format } from "winston";
import config from "./config";

export default function getLogger(
  rateFeed: string,
  traceId: string,
): winston.Logger {
  const isCloudFunction = process.env.FUNCTION_TARGET !== undefined;
  const functionName = process.env.K_SERVICE; // Cloud Run service name (same as function name in Gen 2)
  const revision = process.env.K_REVISION; // Cloud Run revision
  const location = process.env.FUNCTION_REGION; // Region where function is deployed

  const addTraceId = winston.format((info) => {
    info["logging.googleapis.com/trace"] =
      `projects/${config.GCP_PROJECT_ID}/traces/${traceId}`;
    return info;
  });

  const transports: winston.transport[] = [
    // Cloud Logging transport with proper resource descriptor for Cloud Run
    new LoggingWinston({
      projectId: config.GCP_PROJECT_ID,
      labels: {
        rateFeed,
        chain: config.CHAIN,
      },
      // Use the Cloud Run resource descriptor for proper log correlation
      resource:
        isCloudFunction && functionName
          ? {
              type: "cloud_run_revision",
              labels: {
                project_id: config.GCP_PROJECT_ID,
                service_name: functionName,
                revision_name: revision ?? "unknown",
                location: location ?? "unknown",
              },
            }
          : undefined,
      // Don't use prefix as it gets prepended to messages in an ugly way
      useMessageField: false,
    }),
    // Console transport only when running locally, to avoid duplicate logs in GCP
    ...(!isCloudFunction
      ? [
          new winston.transports.Console({
            level: "info",
            format: format.combine(
              format.timestamp(),
              format.printf((log) => {
                return `[${log.level}] ${String(log.timestamp)}: ${log.message as string}`;
              }),
            ),
          }),
        ]
      : []),
  ];

  return winston.createLogger({
    level: "info",
    format: winston.format.combine(addTraceId(), winston.format.json()),
    transports,
  });
}
