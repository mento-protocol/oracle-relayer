locals {
  relayer_addresses = jsondecode(file("${path.module}/relayer_addresses.json"))

  # Map workspace names to chain IDs for use in project naming
  # This keeps the project name under 30 chars while allowing devs to use friendly workspace names
  workspace_to_chain_id = {
    "celo"         = "42220"    # Celo Mainnet
    "celo-sepolia" = "11142220" # Celo Sepolia (Testnet)
  }
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
  labels = {
    "chain" = terraform.workspace
  }
  name   = "${var.project_name}-${terraform.workspace}"
  org_id = var.org_id
  # We use chain IDs (typically shorter) instead of chain names in the project ID to avoid the 30 character length limit
  project_id        = "${var.project_name}-${local.workspace_to_chain_id[terraform.workspace]}"
  random_project_id = true
  source            = "git::https://github.com/terraform-google-modules/terraform-google-project-factory.git?ref=fdc4307ae52565d2385525690de851edb8e38d72" # commit hash of v18.1.0

}

output "project_id" {
  value = module.oracle_relayer.project_id
}
