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

variable "relayer_mnemonic_secret_id" {
  type    = string
  default = "relayer-mnemonic"
}

variable "relayer_mnemonic" {
  type      = string
  sensitive = true
}

# Webhook URL to send monitoring alerts from within GCP Monitoring
# You can find this URL in Victorops by going to "Integrations" -> "Stackdriver".
# The routing key can be found under "Settings" -> "Routing Keys"
variable "victorops_webhook_url" {
  type      = string
  sensitive = true
}

# You can look this up via:
#  `gcloud secrets list`
variable "discord_webhook_url_secret_id" {
  type    = string
  default = "discord-webhook-url"
}

# You can look this up either on the Discord Channel settings, or fetch it from Secret Manager via:
#  `gcloud secrets versions access latest --secret discord-webhook-url-staging`
variable "discord_webhook_url_staging" {
  type      = string
  sensitive = true
}

# You can look this up either on the Discord Channel settings, or fetch it from Secret Manager via:
#  `gcloud secrets versions access latest --secret discord-webhook-url-prod`
variable "discord_webhook_url_prod" {
  type      = string
  sensitive = true
}



#####################################################################################
# The below are mainly kept in vars so we can read them easier in the shell scripts #
#####################################################################################
variable "terraform_service_account" {
  type        = string
  description = "Service account of our Terraform GCP Project which can be impersonated to create and destroy resources in this project"
  default     = "org-terraform@mento-terraform-seed-ffac.iam.gserviceaccount.com"
}

# For consistency we also keep this variable in here, although it's not used in the Terraform code (only in the shell scripts)
# trunk-ignore(tflint/terraform_unused_declarations)
variable "terraform_seed_project_id" {
  type        = string
  description = "The GCP Project ID of the Terraform Seed Project housing the terraform state of all projects"
  default     = "mento-terraform-seed-ffac"
}

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
