resource "google_cloudfunctions2_function" "relay" {
  for_each    = local.chain_configs
  project     = module.oracle_relayer.project_id
  location    = var.region
  name        = "relay-${each.key}"
  description = "Listens to relay events from Pub/Sub and executes the relay request against the `relayer_address` param of the event."

  build_config {
    runtime         = "nodejs22"
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
      DISCORD_WEBHOOK_URL_SECRET_ID = google_secret_manager_secret.discord_webhook_url.secret_id
      RELAYER_MNEMONIC_SECRET_ID    = google_secret_manager_secret.relayer_mnemonic.secret_id
      # Logs execution ID for easier debugging => https://cloud.google.com/functions/docs/monitoring/logging#viewing_runtime_logs
      LOG_EXECUTION_ID = "true"
      NODE_ENV         = each.value.is_production ? "production" : "development"
      CHAIN            = each.key
    }
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.relay[each.key].id
    retry_policy          = "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = module.oracle_relayer.service_account_email
  }
}

resource "google_cloud_run_service_iam_member" "invoker" {
  for_each = local.chain_configs
  project  = module.oracle_relayer.project_id
  location = google_cloudfunctions2_function.relay[each.key].location
  service  = google_cloudfunctions2_function.relay[each.key].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${module.oracle_relayer.service_account_email}"
}

resource "google_cloudfunctions2_function" "mock_aggregator_updater" {
  for_each    = local.mock_aggregator_updater_chain_configs
  project     = module.oracle_relayer.project_id
  location    = var.region
  name        = "update-mock-aggregators-${each.key}"
  description = "Updates testnet mock Chainlink aggregators with latest mainnet Chainlink prices."

  build_config {
    runtime         = "nodejs22"
    entry_point     = "updateMockAggregators"
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
    timeout_seconds       = 180

    environment_variables = {
      GCP_PROJECT_ID                                 = module.oracle_relayer.project_id
      DISCORD_WEBHOOK_URL_SECRET_ID                  = google_secret_manager_secret.discord_webhook_url.secret_id
      RELAYER_MNEMONIC_SECRET_ID                     = google_secret_manager_secret.relayer_mnemonic.secret_id
      MOCK_AGGREGATOR_REPORTER_PRIVATE_KEY_SECRET_ID = google_secret_manager_secret.mock_aggregator_reporter_private_key[0].secret_id
      MOCK_AGGREGATOR_BATCH_REPORTER_ADDRESS         = var.mock_aggregator_batch_reporter_addresses[each.key]
      MOCK_AGGREGATOR_MAPPINGS_JSON                  = jsonencode(local.mock_aggregator_mappings)
      LOG_EXECUTION_ID                               = "true"
      NODE_ENV                                       = "development"
      CHAIN                                          = each.key
    }
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.mock_aggregator_updates[each.key].id
    retry_policy          = "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = module.oracle_relayer.service_account_email
  }
}

resource "google_cloud_run_service_iam_member" "mock_aggregator_updater_invoker" {
  for_each = local.mock_aggregator_updater_chain_configs
  project  = module.oracle_relayer.project_id
  location = google_cloudfunctions2_function.mock_aggregator_updater[each.key].location
  service  = google_cloudfunctions2_function.mock_aggregator_updater[each.key].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${module.oracle_relayer.service_account_email}"
}

# Compute a hash of the source files to detect actual changes
# This is more reliable than using the zip's SHA256 which includes metadata
locals {
  source_files = fileset("${path.module}/..", "src/**")
  package_files = [
    "${path.module}/../package.json",
    "${path.module}/../package-lock.json",
    "${path.module}/mock_aggregator_mappings.json"
  ]
  # Create a hash of all source files and package files
  source_hash = md5(join("", [
    for f in sort(concat(tolist(local.source_files), local.package_files)) :
    fileexists("${path.module}/../${f}") ? filemd5("${path.module}/../${f}") : filemd5(f)
  ]))
}

# Zip the Cloud Function source code
data "archive_file" "function_source" {
  type        = "zip"
  source_dir  = "${path.module}/.."
  output_path = "${path.module}/../function-source.zip"

  # Not sure if this is stricly necessary when defining a .gcloudignore file, but better safe than sorry
  excludes = [".cursor",
    ".DS_Store",
    ".env",
    ".env.example",
    ".env.yaml",
    ".git",
    ".github",
    ".gitignore",
    ".project_vars_cache",
    ".terraform",
    ".terraform.lock.hcl",
    ".trunk",
    ".vscode",
    "DEPLOY_FROM_SCRATCH.md",
    "MIGRATION_PLAN.md",
    "README.md",
    "bin",
    "commitlint.config.mjs",
    "dist",
    "eslint.config.mjs",
    "function-source.zip",
    "infra",
    "node_modules",
    "src/aegis-export.ts",
  ]
}

# Storage Bucket for the Cloud Function source code
resource "google_storage_bucket" "relay_function" {
  project                     = module.oracle_relayer.project_id
  name                        = "${module.oracle_relayer.project_id}-relay-function-source" # Every bucket name must be globally unique
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
  # Use our custom source hash instead of the archive's SHA256
  # This ensures the function only redeploys when actual source files change
  name   = "function-source-${local.source_hash}.zip"
  bucket = google_storage_bucket.relay_function.name
  source = data.archive_file.function_source.output_path
}

# Storage Bucket for access logs
resource "google_storage_bucket" "logging" {
  #checkov:skip=CKV_GCP_62:The logging bucket can't log to itself (circular dependency)
  project                     = module.oracle_relayer.project_id
  name                        = "${module.oracle_relayer.project_id}-logging" # Every bucket name must be globally unique
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
  # checkov:skip=CKV_GCP_49:The cloudbuild builder role should be safe to assign
  # See https://docs.prismacloud.io/en/enterprise-edition/policy-reference/google-cloud-policies/google-cloud-iam-policies/bc-gcp-iam-10
  member = "serviceAccount:${module.oracle_relayer.service_account_email}"
}

# Allows the cloud function to access secrets (i.e. the relayer private key) stored in Secret Manager
resource "google_project_iam_member" "secret_accessor" {
  project = module.oracle_relayer.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${module.oracle_relayer.service_account_email}"
}

# Allow the Cloud Functions service agent to pull container images from Artifact Registry
resource "google_project_iam_member" "functions_artifact_registry" {
  project = module.oracle_relayer.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:service-${module.oracle_relayer.project_number}@gcf-admin-robot.iam.gserviceaccount.com"

  depends_on = [module.oracle_relayer]
}

output "function_uris" {
  value = {
    for chain, fn in google_cloudfunctions2_function.relay : chain => fn.service_config[0].uri
  }
}
