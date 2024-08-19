variable "terraform_seed_project_id" {
  type        = string
  description = "The GCP Project ID of the Terraform Seed Project housing the terraform state of all projects"
  default     = "mento-terraform-seed-ffac"
}

variable "terraform_service_account" {
  type        = string
  description = "Service account of our Terraform GCP Project which can be impersonated to create and destroy resources in this project"
  default     = "org-terraform@mento-terraform-seed-ffac.iam.gserviceaccount.com"
}

variable "project_name" {
  type        = string
  description = "Google Cloud Project Name of the Oracle Relayer Project"
  # Can be at most 26 characters long (30 characters - 4 characters for the auto-generated suffix)
  default = "oracle-relayer"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

# You can find our org id via `gcloud organizations list`
variable "org_id" {
  type = string
}

# You can find the billing account via `gcloud billing accounts list` (pick the GmbH account)
variable "billing_account" {
  type = string
}

variable "relayer_pk_secret_id" {
  type    = string
  default = "relayer-private-key"
}

variable "relayer_pk" {
  type      = string
  sensitive = true
}

###################################################################################
# The below are only kept in vars so we can read them easier in the shell scripts #
###################################################################################
variable "function_name" {
  type    = string
  default = "relay-function"
}

variable "function_entry_point" {
  type    = string
  default = "relay"
}

variable "pubsub_topic" {
  type    = string
  default = "relay-requested"
}

variable "scheduler_job_name" {
  type    = string
  default = "request-relay"
}
