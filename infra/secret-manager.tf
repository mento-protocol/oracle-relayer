resource "google_secret_manager_secret" "relayer_mnemonic" {
  project   = module.oracle_relayer.project_id
  secret_id = var.relayer_mnemonic_secret_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "relayer_mnemonic" {
  secret      = google_secret_manager_secret.relayer_mnemonic.id
  secret_data = var.relayer_mnemonic
}
