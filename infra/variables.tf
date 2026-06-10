variable "project_name" {
  type        = string
  description = "Google Cloud Project Name of the Oracle Relayer Project"
  default     = "oracle-relayer"
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

variable "mock_aggregator_reporter_private_key_secret_id" {
  type    = string
  default = "mock-aggregator-reporter-private-key"
}

variable "mock_aggregator_reporter_private_key" {
  type      = string
  sensitive = true
  default   = ""
}

# Optional dedicated RPC URL for Celo mainnet (e.g. a QuickNode HTTPS endpoint).
# When set, the relayer uses it as the primary RPC and falls back to the chain's
# default public RPC (Forno). Leave empty to use only the default public RPC.
# The default public RPCs are load-balanced across nodes at differing chain
# heights, whose lagging reads cause "nonce too low" rejections.
variable "celo_rpc_url" {
  type      = string
  sensitive = true
  default   = ""
}

variable "rpc_url_secret_id" {
  type    = string
  default = "celo-rpc-url"
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
variable "slack_bot_token_secret_id" {
  type    = string
  default = "slack-bot-token"
}

# Bot User OAuth Token (xoxb-...) of the shared Mento alerts Slack app (the
# same app the monitoring monorepo's Grafana contact points use). Needs the
# chat:write + chat:write.public scopes. Used by the relayer for app-level
# alerts (invalid price, stuck tx) — messages are prefixed with [chain][feed]
# and post to #alerts-oracles (mainnet) / #alerts-testnet (testnet).
variable "slack_bot_token" {
  type      = string
  sensitive = true

  validation {
    condition     = startswith(var.slack_bot_token, "xoxb-")
    error_message = "The slack_bot_token value must be a Slack bot OAuth token starting with 'xoxb-'."
  }
}

# Chain to use for local development .env file generation
variable "local_dev_chain" {
  type    = string
  default = "celo-sepolia"
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

variable "function_entry_point" {
  type    = string
  default = "relay"
}

variable "scheduler_job_name" {
  type    = string
  default = "request-relay"
}
