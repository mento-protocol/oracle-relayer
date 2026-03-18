resource "local_file" "env_file" {
  filename = "${path.module}/../.env"
  content  = <<-EOT
    REFILLER_PRIVATE_KEY=
    GCP_PROJECT_ID=${module.oracle_relayer.project_id}
    DISCORD_WEBHOOK_URL_TESTNET=${var.discord_webhook_url_testnet}
    DISCORD_WEBHOOK_URL_MAINNET=${var.discord_webhook_url_mainnet}
    DISCORD_WEBHOOK_URL_SECRET_ID=${var.discord_webhook_url_secret_id}-${terraform.workspace}
    RELAYER_MNEMONIC_SECRET_ID=${var.relayer_mnemonic_secret_id}
    CHAIN=${var.local_dev_chain}
  EOT
}
