locals {
  every_minute_schedule  = "* * * * *"
  weekly_monday_schedule = "0 6 * * 1" # Mondays at 06:00 UTC

  scheduler_schedule    = terraform.workspace == "mainnet" ? local.every_minute_schedule : local.weekly_monday_schedule
  scheduler_description = terraform.workspace == "mainnet" ? "every minute" : "once a week (Mondays at 06:00 UTC)"
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
