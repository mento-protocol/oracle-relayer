resource "local_file" "env_file" {
  filename = "${path.module}/../.env"
  content  = <<-EOT
    REFILLER_PRIVATE_KEY=
    GCP_PROJECT_ID=${module.oracle_relayer.project_id}
    SLACK_WEBHOOK_URL_SECRET_ID=${var.slack_webhook_url_secret_id}
    RELAYER_MNEMONIC_SECRET_ID=${var.relayer_mnemonic_secret_id}
    CHAIN=${var.local_dev_chain}
  EOT
}
