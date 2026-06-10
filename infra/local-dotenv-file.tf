resource "local_file" "env_file" {
  filename = "${path.module}/../.env"
  content  = <<-EOT
    REFILLER_PRIVATE_KEY=
    GCP_PROJECT_ID=${module.oracle_relayer.project_id}
    SLACK_BOT_TOKEN_SECRET_ID=${var.slack_bot_token_secret_id}
    SLACK_CHANNEL=${local.slack_channel}
    RELAYER_MNEMONIC_SECRET_ID=${var.relayer_mnemonic_secret_id}
    CHAIN=${var.local_dev_chain}
  EOT
}
