terraform {
  required_version = ">= 1.8"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.36.0"
    }
  }
}

module "project-factory" {
  source  = "terraform-google-modules/project-factory/google"
  version = ">= 15.0.1"

  name              = var.project_name
  random_project_id = true
  org_id            = var.org_id
  billing_account   = var.billing_account

  # Disable the default service account in favor of a project-level service account with narrower permissions
  default_service_account = "disable"
  create_project_sa       = true

  # Bucket for Terraform State
  bucket_name          = "terraform-state"
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
    "storage-api.googleapis.com",
  ]
}
