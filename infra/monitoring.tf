# Creates a metric that counts the number of log entries containing 'Relay succeeded' in the relay cloud function.
resource "google_logging_metric" "successful_relay_count" {
  project     = module.oracle_relayer.project_id
  name        = "successful_relay_count"
  description = "Number of log entries containing 'Relay succeeded' in the relay cloud function"
  filter      = <<EOF
    severity=DEFAULT
    SEARCH("`Relay succeeded`")
    resource.labels.service_name="${google_cloudfunctions2_function.relay.name}"
  EOF
}

# Discord notification channel for info-only alerts
resource "google_monitoring_notification_channel" "discord_channel" {
  project      = module.oracle_relayer.project_id
  display_name = "Discord #relayer-alerts"
  type         = "webhook_tokenauth"

  labels = {
    url = var.discord_webhook_url
  }
}

# Splunk notification channel for on-call alerts
resource "google_monitoring_notification_channel" "victorops_channel" {
  project      = module.oracle_relayer.project_id
  display_name = "Splunk (VictorOps)"
  type         = "webhook_tokenauth"

  labels = {
    url = var.victorops_webhook_url
  }
}

# Creates an alert policy that triggers when no successful relay logs have been received in the last 30 minutes,
# and sends a notification to Splunk.
resource "google_monitoring_alert_policy" "successful_relay_policy" {
  project      = module.oracle_relayer.project_id
  display_name = "no-successful-relay-logs"
  combiner     = "OR"
  enabled      = true

  documentation {
    content = "No successful relay events have been logged in the last 30 minutes"
  }

  conditions {
    display_name = "No successful relay logs in 30 minutes"

    condition_threshold {
      filter = <<EOF
        resource.type = "cloud_run_revision" AND
        metric.type   = "logging.googleapis.com/user/${google_logging_metric.successful_relay_count.name}"
      EOF

      duration        = "300s" # Re-test the condition every 5 minutes
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period     = "1800s" # 1 hour
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.victorops_channel.id]
  severity              = "CRITICAL"
}
