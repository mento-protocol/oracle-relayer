import { LoggingWinston } from "@google-cloud/logging-winston";
import type { LogEntry } from "winston";
import winston, { format } from "winston";

export default function getLogger(rateFeed: string): winston.Logger {
  const isCloudFunction = process.env.FUNCTION_TARGET !== undefined;
  const transports: winston.transport[] = [
    // Cloud Logging transport
    new LoggingWinston({ labels: { rateFeed }, prefix: rateFeed }),
    // Console transport only when running locally, to avoid duplicate logs in GCP
    ...(!isCloudFunction
      ? [
          new winston.transports.Console({
            level: "info",
            format: format.combine(
              format.timestamp(),
              format.printf((log: LogEntry) => {
                return `[${log.level}] ${String(log.timestamp)}: [${rateFeed}] ${log.message}`;
              }),
            ),
          }),
        ]
      : []),
  ];

  return winston.createLogger({
    level: "info",
    transports,
  });
}
