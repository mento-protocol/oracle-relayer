resource "local_file" "env_file" {
  filename = "${path.module}/../.env"
  content  = <<-EOT
    GCP_PROJECT_ID=${module.oracle_relayer.project_id}
    DISCORD_WEBHOOK_URL=${var.discord_webhook_url}
    DISCORD_WEBHOOK_URL_SECRET_ID=${var.discord_webhook_url_secret_id}
    RELAYER_MNEMONIC_SECRET_ID=${var.relayer_mnemonic_secret_id}
  EOT
}
