resource "google_secret_manager_secret" "relayer_pk" {
  project   = module.project-factory.project_id
  secret_id = var.relayer_pk_secret_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "relayer_pk" {
  secret      = google_secret_manager_secret.relayer_pk.id
  secret_data = var.relayer_pk
}
