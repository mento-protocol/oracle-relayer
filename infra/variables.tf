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

# You can find the org admins group via:
#  `gcloud organizations get-iam-policy <our-org-id> --format=json | jq -r '.bindings[] | select(.role | startswith("roles/resourcemanager.organizationAdmin"))  | .members[] | select(startswith("group:")) | sub("^group:"; "")'`
variable "group_org_admins" {
  type = string
}

# You can find the billing admins group via:
#  `gcloud organizations get-iam-policy <our-org-id> --format=json | jq -r '.bindings[] | select(.role | startswith("roles/billing.admin"))  | .members[] | select(startswith("group:")) | sub("^group:"; "")'`
variable "group_billing_admins" {
  type = string
}

#####################################################################################
# The below are mainly kept in vars so we can read them easier in the shell scripts #
#####################################################################################
variable "function_name" {
  type = string
  default = "relay-function"
}

variable "function_entry_point" {
  type = string
  default = "relay"
}

variable "pubsub_topic" {
  type = string
  default = "relay-requested"
}
