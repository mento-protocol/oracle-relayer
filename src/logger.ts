import { LoggingWinston } from "@google-cloud/logging-winston";
import type { LogEntry } from "winston";
import winston, { format } from "winston";
import config from "./config";

export default function getLogger(
  rateFeed: string,
  network: string,
  traceId: string,
): winston.Logger {
  const isCloudFunction = process.env.FUNCTION_TARGET !== undefined;

  const addTraceId = winston.format((info) => {
    info["logging.googleapis.com/trace"] =
      `projects/${config.GCP_PROJECT_ID}/traces/${traceId}`;
    return info;
  });

  const transports: winston.transport[] = [
    // Cloud Logging transport
    new LoggingWinston({
      labels: { rateFeed, network },
      prefix: `${rateFeed} ${network}`,
    }),
    // Console transport only when running locally, to avoid duplicate logs in GCP
    ...(!isCloudFunction
      ? [
          new winston.transports.Console({
            level: "info",
            format: format.combine(
              format.timestamp(),
              format.printf((log: LogEntry) => {
                return `[${log.level}] ${String(log.timestamp)}: [${rateFeed}] [${network}] ${log.message}`;
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
