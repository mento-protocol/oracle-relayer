resource "local_file" "env_file" {
  filename = "${path.module}/../.env"
  content  = <<-EOT
    GCP_PROJECT_ID=${module.project-factory.project_id}
    RELAYER_PK_SECRET_ID=${var.relayer_pk_secret_id}
  EOT
}
