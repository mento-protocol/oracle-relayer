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

# Dedicated Celo mainnet RPC URL (e.g. a QuickNode HTTPS endpoint). Optional:
# created only on the mainnet workspace when `celo_rpc_url` is set. The relayer
# uses it as its primary RPC and falls back to the public Forno RPC, which is
# load-balanced across lagging nodes (cause of "nonce too low" rejections).
# Consumed by the celo cloud function via the RPC_URL_SECRET_ID env var.
resource "google_secret_manager_secret" "celo_rpc_url" {
  count     = terraform.workspace == "mainnet" && local.celo_rpc_url_enabled ? 1 : 0
  project   = module.oracle_relayer.project_id
  secret_id = var.rpc_url_secret_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "celo_rpc_url" {
  count       = terraform.workspace == "mainnet" && local.celo_rpc_url_enabled ? 1 : 0
  secret      = google_secret_manager_secret.celo_rpc_url[0].id
  secret_data = var.celo_rpc_url
}
