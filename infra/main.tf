terraform {
  required_version = ">= 1.8"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.36.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.2"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.2"
    }
  }

  backend "gcs" {
    bucket = "terraform-state-da78"
  }

}

resource "random_id" "project_suffix" {
  byte_length = 2
}

module "project-factory" {
  source = "git::https://github.com/terraform-google-modules/terraform-google-project-factory.git?ref=9ac04a6868cadea19a5c016d4d0a4ae35d378b05" # commit hash of v15.0.1

  project_id        = "${var.project_name}-${random_id.project_suffix.hex}"
  random_project_id = false # We generate our own above so we can use it in this module block for the bucket name
  name              = var.project_name
  org_id            = var.org_id
  billing_account   = var.billing_account

  # Disable the default service account in favor of a project-level service account with narrower permissions
  default_service_account = "disable"
  create_project_sa       = true

  # Bucket for Terraform State
  bucket_project       = "${var.project_name}-${random_id.project_suffix.hex}"
  bucket_name          = "terraform-state-${random_id.project_suffix.hex}"
  bucket_location      = var.region
  bucket_versioning    = true
  bucket_force_destroy = true

  activate_apis = [
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudscheduler.googleapis.com",
    "eventarc.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "storage-api.googleapis.com",
  ]
}
