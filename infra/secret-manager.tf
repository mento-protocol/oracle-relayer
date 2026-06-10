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

# Slack bot token used for app-level alert messages (chat.postMessage to
# #alerts-oracles / #alerts-testnet — see local.slack_channel in main.tf).
# Consumed by the cloud functions via SLACK_BOT_TOKEN_SECRET_ID.
resource "google_secret_manager_secret" "slack_bot_token" {
  project   = module.oracle_relayer.project_id
  secret_id = var.slack_bot_token_secret_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "slack_bot_token" {
  secret      = google_secret_manager_secret.slack_bot_token.id
  secret_data = var.slack_bot_token
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
