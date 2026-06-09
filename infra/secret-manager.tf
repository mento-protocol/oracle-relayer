resource "google_secret_manager_secret" "relayer_mnemonic" {
  project   = module.oracle_relayer.project_id
  secret_id = var.relayer_mnemonic_secret_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "relayer_mnemonic" {
  secret      = google_secret_manager_secret.relayer_mnemonic.id
  secret_data = var.relayer_mnemonic
}

resource "google_secret_manager_secret" "mock_aggregator_reporter_private_key" {
  count     = terraform.workspace == "testnet" ? 1 : 0
  project   = module.oracle_relayer.project_id
  secret_id = var.mock_aggregator_reporter_private_key_secret_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "mock_aggregator_reporter_private_key" {
  count       = terraform.workspace == "testnet" ? 1 : 0
  secret      = google_secret_manager_secret.mock_aggregator_reporter_private_key[0].id
  secret_data = var.mock_aggregator_reporter_private_key
}

resource "google_secret_manager_secret" "discord_webhook_url" {
  project   = module.oracle_relayer.project_id
  secret_id = "${var.discord_webhook_url_secret_id}-${terraform.workspace}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "discord_webhook_url" {
  secret      = google_secret_manager_secret.discord_webhook_url.id
  secret_data = local.discord_webhook_url
}
