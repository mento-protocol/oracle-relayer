locals {
  relayer_addresses = jsondecode(file("${path.module}/relayer_addresses.json"))

  environment_chains = {
    "testnet" = ["celo-sepolia", "monad-testnet", "polygon-testnet"]
    "mainnet" = ["celo", "monad"]
  }

  chains = local.environment_chains[terraform.workspace]

  mock_aggregator_updater_chains = terraform.workspace == "testnet" ? ["celo-sepolia", "monad-testnet", "polygon-testnet"] : []

  chain_configs = {
    for chain in local.chains : chain => {
      relayer_addresses = local.relayer_addresses[chain]
      is_production     = terraform.workspace == "mainnet"
      # Only celo (mainnet) uses a dedicated RPC URL for now; null => default public RPC
      rpc_url_secret_id = (chain == "celo" && var.celo_rpc_url != "") ? var.rpc_url_secret_id : null
    }
  }

  mock_aggregator_updater_chain_configs = {
    for chain in local.mock_aggregator_updater_chains : chain => local.chain_configs[chain]
  }

  discord_webhook_url = terraform.workspace == "mainnet" ? var.discord_webhook_url_mainnet : var.discord_webhook_url_testnet

  # Flattened scheduler jobs: "chain/rate_feed" => {chain, key, address}
  all_scheduler_jobs = merge([
    for chain, config in local.chain_configs : {
      for feed, addr in config.relayer_addresses :
      "${chain}/${feed}" => {
        chain           = chain
        rate_feed_key   = feed
        relayer_address = addr
        # CELO/XXX pairs (except CELO/USD) are gas feeds, which don't need
        # frequent updates, so on Celo mainnet they only run once a day.
        is_gas_feed = (
          terraform.workspace == "mainnet" &&
          chain == "celo" &&
          startswith(feed, "celo_") &&
          feed != "celo_usd"
        )
      }
    }
  ]...)
}

provider "google" {
  impersonate_service_account = var.terraform_service_account
}

module "oracle_relayer" {
  activate_apis = [
    "artifactregistry.googleapis.com",
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
    "environment" = terraform.workspace
  }
  name              = "${var.project_name}-${terraform.workspace}"
  org_id            = var.org_id
  project_id        = "${var.project_name}-${terraform.workspace}"
  random_project_id = true
  source            = "git::https://github.com/terraform-google-modules/terraform-google-project-factory.git?ref=fdc4307ae52565d2385525690de851edb8e38d72" # commit hash of v18.1.0

}

output "project_id" {
  value = module.oracle_relayer.project_id
}
