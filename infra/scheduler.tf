# Create PHP/USD Scheduler job
resource "google_cloud_scheduler_job" "php_usd" {
  project     = module.project-factory.project_id
  region      = var.region
  name        = var.scheduler_job_name
  description = "Emits a 'RelayRequested' event to Pub/Sub every minute with a rate feed name and a relayer address as parameters."
  schedule    = "* * * * *" # Run every minute

  pubsub_target {
    topic_name = google_pubsub_topic.relay_requested.id
    data = base64encode(jsonencode({
      rate_feed_name = "PHP/USD"
      # TODO: Replace with the actual relayer address for PHP/USD after it's deployed
      relayer_address = "0xefb84935239dacdecf7c5ba76d8de40b077b7b33"
    }))
  }
}
