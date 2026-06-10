# Creates a metric per chain that counts the number of log entries containing 'Relay succeeded' in the relay cloud function.
resource "google_logging_metric" "successful_relay_count" {
  for_each    = local.chain_configs
  project     = module.oracle_relayer.project_id
  name        = "successful_relay_count_${each.key}"
  description = "Number of log entries containing 'Relay succeeded' in the ${each.key} relay cloud function"
  # NOTE: the relayer logs through the Cloud Logging API (winston) with a
  # cloud_run_revision resource — gen2 functions never emit the gen1
  # cloud_function/function_name labels, so filtering on those matches nothing.
  filter = <<EOF
    severity>=DEFAULT
    SEARCH("`Relay succeeded`")
    resource.type="cloud_run_revision"
    resource.labels.service_name="relay-${each.key}"
  EOF

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"

    labels {
      key = "ratefeed"
    }
  }

  label_extractors = {
    "ratefeed" = "EXTRACT(labels.rateFeed)"
  }
}

# Discord notification channel for info-only alerts
resource "google_monitoring_notification_channel" "discord_channel" {
  project      = module.oracle_relayer.project_id
  display_name = "Discord #${terraform.workspace}-oracle-relayers"
  type         = "webhook_tokenauth"

  labels = {
    url = local.discord_webhook_url
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

# Creates an alert policy per chain that triggers when no successful relay logs have been received in the last 30 minutes,
# and sends a notification to Splunk.
resource "google_monitoring_alert_policy" "successful_relay_policy" {
  for_each     = local.chain_configs
  project      = module.oracle_relayer.project_id
  display_name = "no-successful-relay-logs-${each.key}"
  combiner     = "OR" # Not used in practice because we only have one condition, but it's required by the API
  enabled      = true

  documentation {
    content = "No successful relay events on ${each.key} in the past 30 minutes — the relay function has likely stopped relaying entirely. Per-feed staleness is covered by the Grafana oracle-liveness alerts."
  }

  conditions {
    display_name = "No successful relay logs for ${each.key} in 30 minutes"

    # condition_absent instead of a LT-threshold: a log-based DELTA metric emits
    # NO points at all when nothing matches, and a threshold condition does not
    # evaluate on missing data — i.e. the exact scenario this alert exists for
    # (relays stopped entirely) would never page. Absence is the canonical
    # "no logs in X minutes" shape. Scoped per chain (REDUCE_SUM across feeds);
    # per-feed staleness is the Grafana oracle-liveness alerts' job.
    condition_absent {
      filter = <<EOF
        resource.type = "cloud_run_revision" AND
        metric.type   = "logging.googleapis.com/user/${google_logging_metric.successful_relay_count[each.key].name}"
      EOF

      duration = "1800s" # 30 minutes without a single successful relay on this chain

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_COUNT"
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
