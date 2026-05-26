# Create the Pub/Sub schema
resource "google_pubsub_schema" "relay_schema" {
  for_each   = local.chain_configs
  project    = module.oracle_relayer.project_id
  name       = "relay-schema-${terraform.workspace}-${each.key}"
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

  depends_on = [module.oracle_relayer]
}

# Create the Pub/Sub topic
resource "google_pubsub_topic" "relay" {
  # checkov:skip=CKV_GCP_83:The Pub/Sub messages do not contain sensitive data
  for_each = local.chain_configs
  project  = module.oracle_relayer.project_id
  name     = "relay-${terraform.workspace}-${each.key}"

  labels = {
    rate_feed_name  = "required"
    relayer_address = "required"
  }

  message_retention_duration = "604800s" # 7 days (max. allowed by GCP)

  schema_settings {
    schema   = google_pubsub_schema.relay_schema[each.key].id
    encoding = "JSON"
  }

  depends_on = [module.oracle_relayer]
}

resource "google_pubsub_topic" "mock_aggregator_updates" {
  for_each = local.mock_aggregator_updater_chain_configs
  project  = module.oracle_relayer.project_id
  name     = "mock-aggregator-updates-${each.key}"

  message_retention_duration = "604800s" # 7 days (max. allowed by GCP)

  depends_on = [module.oracle_relayer]
}
