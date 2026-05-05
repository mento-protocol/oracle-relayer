locals {
  every_minute_schedule = "* * * * *"
  daily_schedule        = "0 4 * * *" # Daily at 04:00 UTC

  scheduler_schedule    = terraform.workspace == "mainnet" ? local.every_minute_schedule : local.daily_schedule
  scheduler_description = terraform.workspace == "mainnet" ? "every minute" : "once a day (04:00 UTC)"
}

# Create Scheduler jobs to trigger the Cloud Function for each relayer address
resource "google_cloud_scheduler_job" "relay_jobs" {
  for_each = local.all_scheduler_jobs

  project     = module.oracle_relayer.project_id
  region      = var.region
  name        = "${var.scheduler_job_name}-${each.value.rate_feed_key}-${each.value.chain}"
  description = "Emits a relay event for ${each.value.rate_feed_key} on ${each.value.chain} to Pub/Sub ${local.scheduler_description} with the relayer address ${each.value.relayer_address}"
  schedule    = local.scheduler_schedule

  pubsub_target {
    topic_name = google_pubsub_topic.relay[each.value.chain].id
    data = base64encode(jsonencode({
      rate_feed_name  = upper(replace(each.value.rate_feed_key, "_", "/"))
      relayer_address = each.value.relayer_address
    }))
  }
}

resource "google_cloud_scheduler_job" "mock_aggregator_update_jobs" {
  for_each = local.mock_aggregator_updater_chain_configs

  project     = module.oracle_relayer.project_id
  region      = var.region
  name        = "update-mock-aggregators-${each.key}"
  description = "Updates mock Chainlink aggregators on ${each.key} once per day at 00:00 UTC"
  schedule    = "0 0 * * *"
  time_zone   = "Etc/UTC"

  pubsub_target {
    topic_name = google_pubsub_topic.mock_aggregator_updates[each.key].id
    data       = base64encode("{}")
  }
}
