# Create Scheduler jobs to trigger the Cloud Function for each relayer address
resource "google_cloud_scheduler_job" "relay_jobs" {
  # This will iterate over the relayer addresses and create one scheduler job for each
  for_each = local.relayer_addresses[terraform.workspace]

  project     = module.oracle_relayer.project_id
  region      = var.region
  name        = "${var.scheduler_job_name}-${each.key}-${terraform.workspace}"
  description = "Emits a 'RelayRequested' event to Pub/Sub every minute for ${each.key} with a relayer address as parameter."
  schedule    = "* * * * *" # Run every minute

  pubsub_target {
    topic_name = google_pubsub_topic.relay_requested.id
    data = base64encode(jsonencode({
      rate_feed_name  = upper(replace(each.key, "_", "/"))
      relayer_address = each.value
    }))
  }
}
