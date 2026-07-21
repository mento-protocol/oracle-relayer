# Retain per-feed success counts as non-paging telemetry. Paging is owned by
# the market-hours-aware, per-feed Grafana rules in monitoring-monorepo.
resource "google_logging_metric" "successful_relay_count" {
  for_each    = local.chain_configs
  project     = module.oracle_relayer.project_id
  name        = "successful_relay_count_${each.key}"
  description = "Number of log entries containing 'Relay succeeded' in the ${each.key} relay cloud function"

  # The relayer logs through the Cloud Logging API (winston) with a
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
