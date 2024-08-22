resource "local_file" "env_file" {
  filename = "${path.module}/../.env"
  content  = <<-EOT
    GCP_PROJECT_ID=${module.oracle_relayer.project_id}
    RELAYER_MNEMONIC_SECRET_ID=${var.relayer_mnemonic_secret_id}-${terraform.workspace}
  EOT
}
