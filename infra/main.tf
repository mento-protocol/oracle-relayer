locals {
  relayer_addresses = jsondecode(file("${path.module}/relayer_addresses.json"))
}

provider "google" {
  impersonate_service_account = var.terraform_service_account
}

module "oracle_relayer" {
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
  billing_account         = var.billing_account
  create_project_sa       = true
  default_service_account = "disable"
  name                    = "${var.project_name}-${terraform.workspace}"
  org_id                  = var.org_id
  random_project_id       = true
  source                  = "git::https://github.com/terraform-google-modules/terraform-google-project-factory.git?ref=9ac04a6868cadea19a5c016d4d0a4ae35d378b05" # commit hash of v15.0.1
}

output "project_id" {
  value = module.oracle_relayer.project_id
}
