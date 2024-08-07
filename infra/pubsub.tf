# Create the Pub/Sub schema
resource "google_pubsub_schema" "relay_requested_schema" {
  project    = module.project-factory.project_id
  name       = "relay-requested-schema"
  type       = "AVRO"
  definition = <<-EOF
{
  "type": "record",
  "name": "RelayRequested",
  "fields": [
    {
      "name": "rate_feed_name",
      "type": "string"
    },
    {
      "name": "relayer_address",
      "type": "string"
    }
  ]
}
EOF
}

# Create the Pub/Sub topic
resource "google_pubsub_topic" "relay_requested" {
  # checkov:skip=CKV_GCP_83:The Pub/Sub messages do not contain sensitive data
  project = module.project-factory.project_id
  name    = var.pubsub_topic

  labels = {
    rate_feed_name  = "required"
    relayer_address = "required"
  }

  message_retention_duration = "604800s" # 7 days (max. allowed by GCP)

  schema_settings {
    schema   = google_pubsub_schema.relay_requested_schema.id
    encoding = "JSON"
  }
}
