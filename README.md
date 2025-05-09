# Oracle Relayer Infra

- [Local Setup](#local-setup)
- [Switching between Staging and Production environments](#switching-between-staging-and-production-environments)
- [Running and testing the Cloud Function locally](#running-and-testing-the-cloud-function-locally)
- [Debugging Local Problems](#debugging-local-problems)
- [npm tasks and dev scripts](#npm-tasks-and-dev-scripts)
- [Updating the Cloud Function](#updating-the-cloud-function)
- [Deploying a new Oracle Relayer](#deploying-a-new-oracle-relayer)
- [Aegis Export for Monitoring Relayers](#aegis-export-for-monitoring-relayers)

## Local Setup

1. Install the `gcloud` CLI

   ```sh
   # For macOS
   brew install google-cloud-sdk

   # For other systems, see https://cloud.google.com/sdk/docs/install
   ```

1. Install `trunk` (one linter to rule them all)

   ```sh
   # For macOS
   brew install trunk-io

   # For other systems, see https://docs.trunk.io/check/usage
   ```

   Optionally, you can also install the [Trunk VS Code Extension](https://marketplace.visualstudio.com/items?itemName=Trunk.io)

1. Install `jq` (used in a few shell scripts)

   ```sh
   # On macOS
   brew install jq

   # For other systems, see https://jqlang.github.io/jq/
   ```

1. Install `terraform`

   ```sh
   # On macOS
   brew tap hashicorp/tap
   brew install hashicorp/tap/terraform

   # For other systems, see https://developer.hashicorp.com/terraform/install
   ```

1. Run terraform setup script

   ```sh
   # Checks required permissions, provisions terraform providers, modules, and workspaces
   ./bin/set-up-terraform.sh
   ```

1. Set your local `gcloud` project:

   ```sh
   # Points your local gcloud config to the right project and caches values frequently used in shell scripts
   ./bin/get-project-vars.sh
   ```

1. Create a `infra/terraform.tfvars` file. This is like `.env` for Terraform:

   ```sh
   touch infra/terraform.tfvars
   # This file is `.gitignore`d to avoid accidentally leaking sensitive data
   ```

1. Add the following values to your `terraform.tfvars`:

   ```sh
   # Get it via `gcloud organizations list`
   org_id          = "<our-org-id>"

   # Get it via `gcloud billing accounts list` (pick the GmbH account)
   billing_account = "<our-billing-account-id>"

   # Get it via `gcloud secrets versions access latest --secret relayer-mnemonic-staging`
   # Note that the mnemonic is the same for both the staging and prod environments.
   # To fetch secrets, you'll need the `Secret Manager Secret Accessor` IAM role assigned to your Google Cloud Account
   relayer_mnemonic      = "<relayer-mnemonic>"

   # Get it via `gcloud secrets versions access latest --secret discord_webhook_url_staging`
   # Note that the above secret only exists in the oracle-relayer-staging GCP project
   discord_webhook_url_staging      = "<staging-webhook-url>"

   # Get it via `gcloud secrets versions access latest --secret discord_webhook_url_prod`
   # Note that the above secret only exists in the oracle-relayer-prod GCP project
   discord_webhook_url_prod      = "<prod-webhook-url>"

   # Get it from our VictorOps by going to `Integrations` > `Stackdriver` and copying the URL. The routing key can be found under the settings tab
   victorops_webhook_url   = "<victorops-webhook-url>/<victorops-routing-key>"

   ```

1. Verify that everything works

   ```sh
   # See if you can fetch staging logs of the relay cloud function
   npm run logs

   # See if you can fetch prod logs of the relay cloud function
   npm run logs:prod

   # Try running the function locally
   npm run dev

   # Fire a mock request against your local function
   npm test

   # See if you can manually trigger a relay on staging
   npm run test:staging

   # See if you can manually trigger a relay on production
   npm run test:prod
   ```

## Switching between Staging and Production environments

- Most dev scripts accept a `staging|prod` parameter, i.e.:
  - `./bin/test-deployed-function.sh staging`
  - `./bin/get-function-logs.sh prod`
  - `./bin/deploy-via-gcloud.sh staging`
- You can switch your terraform environment manually via `cd infra && terraform workspace select staging|prod`
  - There are also npm scripts that abstract this for convenience like `npm run deploy:staging`

## Running and testing the Cloud Function locally

- `npm install`
- `npm run dev` to start a local cloud function with hot reload
- `npm test` to call the local cloud function with a mocked `RelayRequested` pubsub event

## Debugging Local Problems

For most local `terraform` or `gcloud` problems, your first steps should always be to:

- Clear your cache via `npm run cache:clear`
- Re-run the Terraform setup script via `./bin/set-up-terraform.sh`

## npm tasks and dev scripts

- **Local Function Development**
  - `dev`: Starts a local server for the cloud function code (with hot-reloading via `nodemon`)
  - `start`: Starts a local server for the cloud function code (without hot-reloading)
  - `test`: Triggers a local cloud function server with a mocked PubSub event
- **Switching Between Environments**
  - `staging`: Switches the terraform workspace and your local `gcloud` project to staging
  - `prod`: Switches the terraform workspace and your local `gcloud` project to prod
- **Deploying and Destroying**
  - `deploy:function:staging`: Deploys the cloud function to staging (via `gcloud functions deploy`)
  - `deploy:function:prod`: Deploys the cloud function to production (via `gcloud functions deploy`)
  - `plan:staging`: Shorthand for running `terraform plan` in the `./infra` folder for staging
  - `plan:prod`: Shorthand for running `terraform plan` in the `./infra` folder for production
  - `deploy:staging`: Deploys full project to staging (via `terraform apply`)
  - `deploy:prod`: Deploys full project to production (via `terraform apply`)
  - `destroy:staging`: 🚨 Destroys entire project on staging (via `terraform destroy`)
  - `destroy:prod`: 🚨 Destroys entire project on production (via `terraform destroy`)
- **View Logs**
  - `logs`: Shorthand for fetching the staging cloud function logs from staging
  - `logs:url`: Shorthand for fetching the log explorer URL for the staging function
  - `logs:prod`: Get prod function logs
  - `logs:staging`: Get staging function logs
  - `logs:function:url:prod`: Get log explorer URL for prod function
  - `logs:function:url:staging`: Get log explorer URL for staging function
  - `logs:job`: Get scheduler job logs, requires a rate feed name argument, i.e. `npm run logs:job PHP/USD`
  - `logs:job:url`: Get scheduler job URL, requires a rate feed name argument, i.e. `npm run logs:job:url PHP/USD`
- **Manually triggering a relay**
  - `test:staging`: Triggers a relay on the staging cloud function manually, i.e. `npm run test:staging PHP/USD`
  - `test:prod`: Triggers a relay on the prod cloud function manually, i.e. `npm run test:prod PHP/USD`
- **General Helper & DX Scripts**
  - `cache:clear`: Clears local shell script cache and refresh it with current values
  - `generate:env`: Auto-generates/updates a local `.env` required by a locally running cloud function server
  - `todo`: Lists all `TODO` and `FIXME` comments
  - `get:relayer:signer`: Prints the signer address that calls the relay function on the given ratefeed's relayer contract.
  - `refill:mainnet` or `refill:alfajores`: Refills all relayer signer addresses with a low balance on the given network
- **Shell Scripts**
  - `set-up-terraform.sh`: Checks required IAM permissions, provisions terraform providers, modules, and workspaces
  - `check-gcloud-login.sh`: Checks for Google Cloud login and application-default credentials.

## Refilling relayer signer accounts

The relayer signer addresses run out of CELO from time to time and need to be refilled. This can be done by adding a `REFILLER_PRIVATE_KEY` to the `.env` file (e.g. the deployer private key) and running the `refill:mainnet` or `refill:alfajores` script, which will transfer CELO to all signer addresses running low on balance.

## Updating the Cloud Function

You have two options to deploy the Cloud Function code, `terraform` or `gcloud` cli. Both are perfectly fine to use.

1. Via `terraform` by running `npm run deploy:[staging|prod]`
   - How? The npm task will:
     - Call `terraform apply` with the correct workspace which re-deploys the function with the latest code from your local machine
   - Pros
     - Keeps the terraform state clean
     - Same command for all changes, regardless of infra or cloud function code
   - Cons
     - Less familiar way of deploying cloud functions (if you're used to `gcloud functions deploy`)
     - Less log output
     - Slightly slower because `terraform apply` will always fetch the current state from the cloud storage bucket before deploying
2. Via `gcloud` by running `npm run deploy:function:[staging:prod]`
   - How? The npm task will:
     - Look up the service account used by the cloud function
     - Call `gcloud functions deploy` with the correct parameters
   - Pros
     - Familiar way of deploying cloud functions
     - More log output making deployment failures slightly faster to debug
     - Slightly faster because we're skipping the terraform state lookup
   - Cons
     - Will lead to inconsistent terraform state (because terraform is tracking the function source code and its version)
     - Different commands to remember when updating infra components vs cloud function source code
     - Will only work for updating a pre-existing cloud function's code, will fail for a first-time deploy

## Deploying a new Oracle Relayer

1. Deploy the new relayer contracts via the [relayer factory](https://github.com/mento-protocol/mento-core/blob/develop/contracts/oracles/ChainlinkRelayerFactory.sol). Exemplary deployment scripts can be found in the [MU07 Deployment Scripts](https://github.com/mento-protocol/mento-deployment/blob/main/script/upgrades/MU07/deploy/MU07-Deploy-ChainlinkRelayers.sol)
1. Ensure the new relayers have been whitelisted in SortedOracles on both Alfajores and Mainnet (otherwise all relay() transactions will fail)
1. Add the addresses of the deployed relayers to [relayer_addresses.json](./infra/relayer_addresses.json) (alfajores relayers under `staging`, mainnet relayers under `prod`)
1. Run `npm run deploy:staging` and/or `npm run deploy:prod` to create GCP cloud scheduler jobs for the new relayers
1. [Add the new relayers to aegis for monitoring](#aegis-export-for-monitoring-relayers)

## Aegis Export for Monitoring Relayers

1. Run `npm run aegis:export` to print out an aegis config template in your local CLI
1. Copy the relevant sections for the relayers you want to add to aegis
1. Paste them into [aegis' config.yaml](https://github.com/mento-protocol/aegis/blob/main/config.yaml)
1. Run aegis in dev mode via `npm run dev`, check that there are no errors in the log outputs
1. Submit a PR with your changes
1. After successful code review, deploy your changes via `npm run deploy` in aegis
