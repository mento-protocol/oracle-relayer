resource "local_file" "env_file" {
  filename = "${path.module}/../.env"
  content  = <<-EOT
    GCP_PROJECT_ID=${module.oracle_relayer.project_id}
    DISCORD_WEBHOOK_URL=${var.discord_webhook_url}
    RELAYER_MNEMONIC_SECRET_ID=${var.relayer_mnemonic_secret_id}-${terraform.workspace}
  EOT
}
