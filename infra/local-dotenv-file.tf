resource "local_file" "env_file" {
  filename = "${path.module}/../.env"
  content  = <<-EOT
    GCP_PROJECT_ID=${module.oracle_relayer.project_id}
    DISCORD_WEBHOOK_URL_STAGING=${var.discord_webhook_url_staging}
    DISCORD_WEBHOOK_URL_PROD=${var.discord_webhook_url_prod}
    DISCORD_WEBHOOK_URL_SECRET_ID=${var.discord_webhook_url_secret_id}-${terraform.workspace}
    RELAYER_MNEMONIC_SECRET_ID=${var.relayer_mnemonic_secret_id}
  EOT
}
