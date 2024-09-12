resource "google_cloudfunctions2_function" "relay" {
  project     = module.oracle_relayer.project_id
  location    = var.region
  name        = "${var.function_name}-${terraform.workspace}"
  description = "Listens to 'RelayRequested' events from Pub/Sub and executes the relay request against the `relayer_address` param of the event."

  build_config {
    runtime         = "nodejs20"
    entry_point     = var.function_entry_point
    service_account = module.oracle_relayer.service_account_name

    source {
      storage_source {
        bucket = google_storage_bucket.relay_function.name
        object = google_storage_bucket_object.source_code.name
      }
    }
  }

  service_config {
    available_memory      = "256M"
    ingress_settings      = "ALLOW_INTERNAL_ONLY"
    service_account_email = module.oracle_relayer.service_account_email
    timeout_seconds       = 60

    environment_variables = {
      GCP_PROJECT_ID                = module.oracle_relayer.project_id
      DISCORD_WEBHOOK_URL_SECRET_ID = var.discord_webhook_url_secret_id
      RELAYER_MNEMONIC_SECRET_ID    = google_secret_manager_secret.relayer_mnemonic.secret_id
      # Logs execution ID for easier debugging => https://cloud.google.com/functions/docs/monitoring/logging#viewing_runtime_logs
      LOG_EXECUTION_ID = "true"
      NODE_ENV         = terraform.workspace == "staging" ? "development" : "production"
    }
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.relay_requested.id
    retry_policy          = "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = module.oracle_relayer.service_account_email
  }
}

resource "google_cloud_run_service_iam_member" "invoker" {
  project  = module.oracle_relayer.project_id
  location = google_cloudfunctions2_function.relay.location
  service  = google_cloudfunctions2_function.relay.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${module.oracle_relayer.service_account_email}"
}

# Zip the Cloud Function source code
data "archive_file" "function_source" {
  type        = "zip"
  source_dir  = "${path.module}/.."
  output_path = "${path.module}/../function-source.zip"

  # Not sure if this is stricly necessary when defining a .gcloudignore file, but better safe than sorry
  excludes = [".env", ".env.example", ".env.yaml", ".git", ".gitignore", ".trunk", ".vscode", "README.md", "dist", "commitlint.config.mjs", "eslint.config.mjs", "infra", "node_modules"]
}

# Storage Bucket for the Cloud Function source code
resource "google_storage_bucket" "relay_function" {
  project                     = module.oracle_relayer.project_id
  name                        = "${module.oracle_relayer.project_id}-${terraform.workspace}-relay-function-source" # Every bucket name must be globally unique
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  versioning {
    enabled = true
  }
  logging {
    log_bucket = google_storage_bucket.logging.id
  }

  force_destroy = true
}

# Upload the Cloud Function source code to the Storage Bucket
resource "google_storage_bucket_object" "source_code" {
  name   = "function-source-${terraform.workspace}-${data.archive_file.function_source.output_sha256}.zip"
  bucket = google_storage_bucket.relay_function.name
  source = data.archive_file.function_source.output_path
}

# Storage Bucket for access logs
resource "google_storage_bucket" "logging" {
  #checkov:skip=CKV_GCP_62:The logging bucket can't log to itself (circular dependency)
  project                     = module.oracle_relayer.project_id
  name                        = "${module.oracle_relayer.project_id}-${terraform.workspace}-logging" # Every bucket name must be globally unique
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  force_destroy = true
}

# Allow cloud build to access the function source code in the storage bucket
resource "google_storage_bucket_iam_member" "cloud_build_storage_access" {
  bucket = google_storage_bucket.relay_function.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${module.oracle_relayer.service_account_email}"
}

# Allow cloud build to build the cloud function and write build logs.
resource "google_project_iam_member" "cloudbuild_builder" {
  project = module.oracle_relayer.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${module.oracle_relayer.service_account_email}"
}

# Allows the cloud function to access secrets (i.e. the relayer private key) stored in Secret Manager
resource "google_project_iam_member" "secret_accessor" {
  project = module.oracle_relayer.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${module.oracle_relayer.service_account_email}"
}

output "function_uri" {
  value = google_cloudfunctions2_function.relay.service_config[0].uri
}
