resource "google_secret_manager_secret" "relayer_pk" {
  project   = module.oracle_relayer.project_id
  secret_id = "${var.relayer_pk_secret_id}-${terraform.workspace}"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "relayer_pk" {
  secret      = google_secret_manager_secret.relayer_pk.id
  secret_data = var.relayer_pk
}
