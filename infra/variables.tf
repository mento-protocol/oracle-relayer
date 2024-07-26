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

#####################################################################################
# The below are mainly kept in vars so we can read them easier in the shell scripts #
#####################################################################################
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
