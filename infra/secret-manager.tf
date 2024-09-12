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

# Creates a new secret for the Discord webhook URL.
# Terraform will try to look up the webhook URL from terraform.tfvars,
# and if it can't find it locally it will prompt the user to enter it manually.
resource "google_secret_manager_secret" "discord_webhook_url" {
  project   = module.oracle_relayer.project_id
  secret_id = var.discord_webhook_url_secret_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "discord_webhook_url" {
  secret      = google_secret_manager_secret.discord_webhook_url.id
  secret_data = var.discord_webhook_url
}
