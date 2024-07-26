# TODO: Refactor to create 1 job per relayer instance

# Create the Scheduler job
resource "google_cloud_scheduler_job" "relay_requested_scheduler" {
  project     = module.project-factory.project_id
  region      = var.region
  name        = var.scheduler_job_name
  description = "Emits a 'RelayRequested' event to Pub/Sub every minute with a relayer address as its sole parameter."
  schedule    = "* * * * *" # Run every minute

  pubsub_target {
    topic_name = google_pubsub_topic.relay_requested.id
    data = base64encode(jsonencode({
      # TODO: Replace with the actual relayer address
      relayer_address = "0xefb84935239dacdecf7c5ba76d8de40b077b7b33"
    }))
  }
}
