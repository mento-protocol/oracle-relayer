# Oracle Relayer Infra

- [Local Setup](#local-setup)
- [Switching between environments](#switching-between-environments)
- [Debugging Local Problems](#debugging-local-problems)
- [Viewing Logs](#viewing-logs)
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

1. Install `jq` (used in shell scripts)

   ```sh
   # For macOS
   brew install jq

   # For other systems, see https://jqlang.github.io/jq/
   ```

1. Install `terraform`

   ```sh
   # For macOS
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

   # Get it via `gcloud secrets versions access latest --secret relayer-mnemonic-celo-sepolia`
   # Note that the mnemonic is the same for both the celo-sepolia and celo environments.
   # To fetch secrets, you'll need the `Secret Manager Secret Accessor` IAM role assigned to your Google Cloud Account
   relayer_mnemonic      = "<relayer-mnemonic>"

   # Get it via `gcloud secrets versions access latest --secret discord_webhook_url_celo_sepolia`
   # Note that the above secret only exists in the oracle-relayer-celo-sepolia GCP project
   discord_webhook_url_celo_sepolia      = "<celo-sepolia-webhook-url>"

   # Get it via `gcloud secrets versions access latest --secret discord_webhook_url_celo`
   # Note that the above secret only exists in the oracle-relayer-celo GCP project
   discord_webhook_url_celo      = "<celo-webhook-url>"

   # Get it from our VictorOps by going to `Integrations` > `Stackdriver` and copying the URL. The routing key can be found under the settings tab
   victorops_webhook_url   = "<victorops-webhook-url>/<victorops-routing-key>"

   ```

1. Verify that everything works

   ```sh
   # Switch your local gcloud context to Celo
   npm run celo

   # See if you can fetch celo logs of the relay cloud function
   npm run logs

   # Switch your local gcloud context to Celo Sepolia
   npm run celo-sepolia

   # See if you can fetch celo-sepolia logs of the relay cloud function
   npm run logs

   # Try running the function locally
   npm install
   npm run dev

   # Fire a mock request against your local function
   npm test

   # Optionally accepts a rate feed and relayer contract arg
   npm test "GBP/USD" "0x215d3ba962597DeFb38Da439ED4dB8E8a63e409a"

   # See if you can manually trigger a relay on celo for a specific rate feed
   npm run test:celo "CELO/ETH"

   # See if you can manually trigger a relay on celo-sepolia
   npm run test:celo-sepolia "EUR/USD"
   ```

## Switching between environments

- There is 1 Google Cloud Project per chain where oracle relayers are deployed
- You can quickly switch between these projects (=chains) via `npm run celo`, `npm run celo-sepolia`

### Why is this necessary?

Most dev scripts under [`./bin`](./bin) are using `gcloud` commands.
These `gcloud` commands per default always run against the currently active project.
Alternatively, you'd always need to explicitly pass a `--project-id` flag to every `gcloud` command which can get annoying quickly.

## Debugging Local Problems

For most local `terraform` or `gcloud` problems, your first steps should always be to:

- Clear your local shell script cache via `npm run cache:clear`
- Re-run the Terraform setup script via `./bin/set-up-terraform.sh`

## Viewing Logs

The Oracle Relayer uses structured logging with Google Cloud Logging. Logs include severity levels, timestamps, rate feed labels, and trace IDs for correlating function invocations.

### Quick Start

First, switch to the environment you want to view:

```bash
npm run celo              # Switch to celo
npm run celo-sepolia      # Switch to celo-sepolia
```

### Logs in your CLI

**View recent logs (last 50):**

```bash
npm run logs                     # All logs
npm run logs CELO/USD            # Filter by rate feed
```

**Stream logs in real-time:**

```bash
npm run logs:tail                   # All logs
npm run logs:tail CELO/USD          # Filter by rate feed
```

Press `Ctrl+C` to stop tailing.

### Logs in the Google Cloud Console UI

**Generate Log Explorer URLs:**

```bash
npm run logs:url                      # All logs for current environment
npm run logs:url CELO/USD             # Filter by rate feed
```

This generates URLs for:

- **Logs Explorer** (recommended): Full-featured viewer with filtering and grouping
- **Cloud Run Logs**: For debugging function startup issues (excludes function execution logs)

### Using gcloud Directly

```bash
# View recent logs
gcloud logging read 'resource.labels.service_name="relay-function-celo-sepolia"' --limit 50

# Tail logs in real-time
gcloud beta logging tail 'resource.labels.service_name="relay-function-celo-sepolia"' \
  --format "table(timestamp, severity, labels.rateFeed, jsonPayload.message)"

# Filter by rate feed
gcloud beta logging tail 'resource.labels.service_name="relay-function-celo-sepolia" AND labels.rateFeed="CELO/USD"'
```

### Best Practices

- Use the logger instance (not `console.log`) for structured logging
- Use appropriate severity: `logger.info()` for normal operations, `logger.warn()` for non-blocking issues, `logger.error()` for failures
- Filter by rate feed when debugging specific oracles to reduce noise

## npm tasks and dev scripts

- **Local Function Development**
  - `dev`: Starts a local server for the cloud function code (with hot-reloading via `nodemon`)
  - `start`: Starts a local server for the cloud function code (without hot-reloading)
  - `test`: Triggers a local cloud function server with a mocked PubSub event
- **Switching Between Environments**
  - `celo-sepolia`: Switches the terraform workspace and your local `gcloud` project to celo-sepolia
  - `celo`: Switches the terraform workspace and your local `gcloud` project to celo
- **Deploying and Destroying**
  - `deploy:celo-sepolia`: Deploys full project to celo-sepolia (via `terraform apply`)
  - `deploy:celo`: Deploys full project to celo (via `terraform apply`)
  - `deploy:function:celo-sepolia`: Deploys only the cloud function for the celo-sepolia chain (via `gcloud functions deploy`)
  - `deploy:function:celo`: Deploys only cloud function for the celo chain (via `gcloud functions deploy`)
  - `plan:celo-sepolia`: Shorthand for running `terraform plan` in the `./infra` folder for celo-sepolia
  - `plan:celo`: Shorthand for running `terraform plan` in the `./infra` folder for celo
  - `destroy:celo-sepolia`: 🚨 Destroys entire project on celo-sepolia (via `terraform destroy`)
  - `destroy:celo`: 🚨 Destroys entire project on celo (via `terraform destroy`)
- **View Logs** (see [Viewing Logs](#viewing-logs) section)
  - `logs [RATE_FEED]`: View recent logs (last 50 entries)
  - `logs:tail [RATE_FEED]`: Stream logs in real-time
  - `logs:url [RATE_FEED]`: Generate log explorer URLs for Google Cloud Console
- **Manually Triggering a Relay**
  - `test:celo-sepolia`: Manually trigger a relay on celo-sepolia, e.g. `npm run test:celo-sepolia PHP/USD`
  - `test:celo`: Manually trigger a relay on celo, e.g. `npm run test:celo PHP/USD`
- **General Helper & DX Scripts**
  - `cache:clear`: Clears local shell script cache and refresh it with current values
  - `generate:env`: Auto-generates/updates a local `.env` required by a locally running cloud function server
  - `todo`: Lists all `TODO` and `FIXME` comments
  - `get:relayer:signer`: Prints the signer address that calls the relay function on the given rate feed's relayer contract.
  - `refill:celo` or `refill:celo-sepolia`: Refills all relayer signer addresses with a low balance on the given network
- **Shell Scripts**
  - `set-up-terraform.sh`: Checks required IAM permissions, provisions terraform providers, modules, and workspaces
  - `check-gcloud-login.sh`: Checks for Google Cloud login and application-default credentials.

## Refilling relayer signer accounts

The relayer signer addresses run out of CELO from time to time and need to be refilled. This can be done by adding a `REFILLER_PRIVATE_KEY` to the `.env` file (e.g. the deployer private key) and running the `refill:celo` or `refill:celo-sepolia` script, which will transfer CELO to all signer addresses running low on balance.

## Updating the Cloud Function

You have two options to deploy the Cloud Function code, `terraform` or `gcloud` cli. Both are perfectly fine to use.

1. Via `terraform` by running `npm run deploy:[celo-sepolia|celo]`
   - How? The npm task will:
     - Call `terraform apply` with the correct workspace which re-deploys the function with the latest code from your local machine
   - Pros
     - Keeps the terraform state clean
     - Same command for all changes, regardless of infra or cloud function code
   - Cons
     - Less familiar way of deploying cloud functions (if you're used to `gcloud functions deploy`)
     - Less log output
     - Slightly slower because `terraform apply` will always fetch the current state from the cloud storage bucket before deploying
2. Via `gcloud` by running `npm run deploy:function:[celo-sepolia:celo]`
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
1. Ensure the new relayers have been whitelisted in SortedOracles on both Celo Sepolia and Celo Mainnet (otherwise relay() transactions will fail)
1. Add the addresses of the deployed relayers to [relayer_addresses.json](./infra/relayer_addresses.json) (celo-sepolia relayers under `celo-sepolia`, celo mainnet relayers under `celo`)
1. Run `npm run deploy:celo-sepolia` and/or `npm run deploy:celo` to create GCP cloud scheduler jobs for the new relayers
1. [Add the new relayers to aegis for monitoring](#aegis-export-for-monitoring-relayers)

### Aegis Export for Monitoring Relayers

1. Run `npm run aegis:export` to print out an aegis config template in your local CLI
1. Copy the relevant sections for the relayers you want to add to aegis
1. Paste them into [aegis' config.yaml](https://github.com/mento-protocol/aegis/blob/main/config.yaml)
1. Run aegis in dev mode via `npm run dev`, check that there are no errors in the log outputs
1. Submit a PR with your changes
1. After successful code review, deploy your changes via `npm run deploy` in aegis
