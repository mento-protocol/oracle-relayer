# Oracle Relayer Infra

- [Local Setup](#local-setup)
- [Switching between environments](#switching-between-environments)
- [Debugging Local Problems](#debugging-local-problems)
- [Viewing Logs](#viewing-logs)
- [npm tasks and dev scripts](#npm-tasks-and-dev-scripts)
- [Updating the Cloud Function](#updating-the-cloud-function)
- [Deploying a new Oracle Relayer](#deploying-a-new-oracle-relayer)
- [Aegis Export for Monitoring Relayers](#aegis-export-for-monitoring-relayers)

## Architecture

The oracle relayer infrastructure is organized into **2 GCP projects** — one per environment:

| Environment | GCP Project              | Cloud Functions                                                      | Pub/Sub Topics                                                                               |
| ----------- | ------------------------ | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| testnet     | `oracle-relayer-testnet` | `relay-celo-sepolia`, `relay-monad-testnet`, `relay-polygon-testnet` | `relay-testnet-celo-sepolia`, `relay-testnet-monad-testnet`, `relay-testnet-polygon-testnet` |
| mainnet     | `oracle-relayer-mainnet` | `relay-celo`, `relay-monad`                                          | `relay-mainnet-celo`, `relay-mainnet-monad`                                                  |

Each environment hosts multiple cloud functions (one per chain), sharing the same source code but differentiated by the `CHAIN` environment variable. Terraform workspaces map to environments (`testnet` / `mainnet`), and `for_each` iterates over chains within each workspace.

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

   # Get it via `gcloud secrets versions access latest --secret relayer-mnemonic`
   # Note that the mnemonic is shared across all environments.
   # To fetch secrets, you'll need the `Secret Manager Secret Accessor` IAM role assigned to your Google Cloud Account
   relayer_mnemonic      = "<relayer-mnemonic>"

   # Testnet only: private key authorized to call MockAggregatorBatchReporter.batchReport.
   # The same EOA is used for all supported testnet chains.
   mock_aggregator_reporter_private_key = "<private-key>"

   # Discord webhook URL for testnet alerts
   discord_webhook_url_testnet      = "<testnet-webhook-url>"

   # Discord webhook URL for mainnet alerts
   discord_webhook_url_mainnet      = "<mainnet-webhook-url>"

   # Get it from our VictorOps by going to `Integrations` > `Stackdriver` and copying the URL. The routing key can be found under the settings tab
   victorops_webhook_url   = "<victorops-webhook-url>/<victorops-routing-key>"

   ```

1. Verify that everything works

   ```sh
   # Switch your local gcloud context to the testnet environment
   npm run testnet

   # See if you can fetch logs for a specific chain
   npm run logs:celo-sepolia
   npm run logs:monad-testnet

   # Switch your local gcloud context to the mainnet environment
   npm run mainnet

   # See if you can fetch mainnet logs
   npm run logs:celo
   npm run logs:monad

   # Try running the function locally
   npm install
   npm run dev

   # Fire a mock request against your local function
   npm test

   # Optionally accepts a rate feed and relayer contract arg
   npm test "GBP/USD" "0x215d3ba962597DeFb38Da439ED4dB8E8a63e409a"

   # See if you can manually trigger a relay on celo-sepolia for a specific rate feed
   npm run test:celo-sepolia "EUR/USD"

   # See if you can manually trigger a relay on monad-testnet
   npm run test:monad-testnet "AUSD/USD"
   ```

## Switching between environments

- There are 2 GCP projects: one for testnet chains and one for mainnet chains
- You can quickly switch between environments via `npm run testnet` or `npm run mainnet`
- Each environment hosts multiple chains (e.g., testnet has celo-sepolia and monad-testnet)

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

All log commands require a chain argument:

```bash
npm run logs:celo-sepolia        # View recent celo-sepolia logs
npm run logs:monad-testnet       # View recent monad-testnet logs
npm run logs:celo                # View recent celo mainnet logs
npm run logs:monad               # View recent monad mainnet logs
```

### Logs in your CLI

**View recent logs (last 50):**

```bash
npm run logs:celo-sepolia              # All logs for celo-sepolia
./bin/get-function-logs.sh celo CELO/USD   # Filter by rate feed
```

**Stream logs in real-time:**

```bash
npm run logs:tail:celo-sepolia                   # All logs
./bin/tail-function-logs.sh celo-sepolia CELO/USD   # Filter by rate feed
```

Press `Ctrl+C` to stop tailing.

### Logs in the Google Cloud Console UI

**Generate Log Explorer URLs:**

```bash
npm run logs:url:celo-sepolia                            # All logs
./bin/get-function-logs-url.sh celo-sepolia CELO/USD     # Filter by rate feed
```

This generates URLs for:

- **Logs Explorer** (recommended): Full-featured viewer with filtering and grouping
- **Cloud Run Logs**: For debugging function startup issues (excludes function execution logs)

### Using gcloud Directly

```bash
# View recent logs
gcloud logging read 'resource.labels.service_name="relay-celo-sepolia"' \
  --project oracle-relayer-testnet-XXXX --limit 50

# Tail logs in real-time
gcloud beta logging tail 'resource.labels.service_name="relay-celo-sepolia"' \
  --project oracle-relayer-testnet-XXXX

# Filter by rate feed
gcloud beta logging tail 'resource.labels.service_name="relay-celo-sepolia" AND labels.rateFeed="CELO/USD"' \
  --project oracle-relayer-testnet-XXXX
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
  - `testnet`: Switches the terraform workspace and your local `gcloud` project to testnet
  - `mainnet`: Switches the terraform workspace and your local `gcloud` project to mainnet
- **Deploying and Destroying**
  - `deploy:testnet`: Deploys all testnet chains (via `terraform apply`)
  - `deploy:mainnet`: Deploys all mainnet chains (via `terraform apply`)
  - `deploy:function:celo-sepolia`: Deploys only the cloud function for celo-sepolia (via `gcloud functions deploy`)
  - `deploy:function:monad-testnet`: Deploys only the cloud function for monad-testnet (via `gcloud functions deploy`)
  - `deploy:function:polygon-testnet`: Deploys only the cloud function for polygon-testnet (via `gcloud functions deploy`)
  - `deploy:function:celo`: Deploys only the cloud function for celo (via `gcloud functions deploy`)
  - `deploy:function:monad`: Deploys only the cloud function for monad (via `gcloud functions deploy`)
  - `plan:testnet`: Shorthand for running `terraform plan` for the testnet environment
  - `plan:mainnet`: Shorthand for running `terraform plan` for the mainnet environment
  - `destroy:testnet`: Destroys entire testnet project (via `terraform destroy`)
  - `destroy:mainnet`: Destroys entire mainnet project (via `terraform destroy`)
- **View Logs** (see [Viewing Logs](#viewing-logs) section)
  - `logs:celo-sepolia`: View recent celo-sepolia logs (last 50 entries)
  - `logs:monad-testnet`: View recent monad-testnet logs
  - `logs:celo`: View recent celo mainnet logs
  - `logs:monad`: View recent monad mainnet logs
  - `logs:tail:<chain>`: Stream logs in real-time for a specific chain
  - `logs:url:<chain>`: Generate log explorer URLs for a specific chain
- **Manually Triggering a Relay**
  - `test:celo-sepolia`: Manually trigger a relay on celo-sepolia, e.g. `npm run test:celo-sepolia PHP/USD`
  - `test:monad-testnet`: Manually trigger a relay on monad-testnet, e.g. `npm run test:monad-testnet AUSD/USD`
  - `test:celo`: Manually trigger a relay on celo, e.g. `npm run test:celo CELO/ETH`
  - `test:monad`: Manually trigger a relay on monad, e.g. `npm run test:monad AUSD/USD`
- **General Helper & DX Scripts**
  - `cache:clear`: Clears local shell script cache and refresh it with current values
  - `generate:env`: Auto-generates/updates a local `.env` required by a locally running cloud function server
  - `todo`: Lists all `TODO` and `FIXME` comments
  - `get:relayer:signer`: Prints the signer address that calls the relay function on the given rate feed's relayer contract.
  - `refill:<chain>`: Refills all relayer signer addresses with a low balance on the given network (e.g., `refill:celo`, `refill:celo-sepolia`)
- **Shell Scripts**
  - `set-up-terraform.sh`: Checks required IAM permissions, provisions terraform providers, modules, and workspaces
  - `check-gcloud-login.sh`: Checks for Google Cloud login and application-default credentials.

## Refilling relayer signer accounts

The relayer signer addresses run out of native tokens from time to time and need to be refilled. This can be done by adding a `REFILLER_PRIVATE_KEY` to the `.env` file (e.g. the deployer private key) and running the appropriate refill script, which will transfer tokens to all signer addresses running low on balance.

```bash
npm run refill:celo
npm run refill:celo-sepolia
npm run refill:monad
npm run refill:monad-testnet
```

## Updating the Cloud Function

You have two options to deploy the Cloud Function code, `terraform` or `gcloud` cli. Both are perfectly fine to use.

1. Via `terraform` by running `npm run deploy:[testnet|mainnet]`
   - How? The npm task will:
     - Call `terraform apply` with the correct workspace which re-deploys all functions in the environment with the latest code from your local machine
   - Pros
     - Keeps the terraform state clean
     - Same command for all changes, regardless of infra or cloud function code
     - Deploys all chains in the environment at once
   - Cons
     - Less familiar way of deploying cloud functions (if you're used to `gcloud functions deploy`)
     - Less log output
     - Slightly slower because `terraform apply` will always fetch the current state from the cloud storage bucket before deploying
2. Via `gcloud` by running `npm run deploy:function:[celo-sepolia|monad-testnet|polygon-testnet|celo|monad]`
   - How? The npm task will:
     - Look up the service account used by the cloud function
     - Call `gcloud functions deploy` with the correct parameters
   - Pros
     - Familiar way of deploying cloud functions
     - More log output making deployment failures slightly faster to debug
     - Slightly faster because we're skipping the terraform state lookup
     - Deploys a single chain's function without touching others
   - Cons
     - Will lead to inconsistent terraform state (because terraform is tracking the function source code and its version)
     - Different commands to remember when updating infra components vs cloud function source code
     - Will only work for updating a pre-existing cloud function's code, will fail for a first-time deploy

## Deploying a new Oracle Relayer

1. Deploy the new relayer contracts via the [relayer factory](https://github.com/mento-protocol/mento-core/blob/develop/contracts/oracles/ChainlinkRelayerFactory.sol). Exemplary deployment scripts can be found in the [MU07 Deployment Scripts](https://github.com/mento-protocol/mento-deployment/blob/main/script/upgrades/MU07/deploy/MU07-Deploy-ChainlinkRelayers.sol)
1. Ensure the new relayers have been whitelisted in SortedOracles on the relevant chain (otherwise relay() transactions will fail)
1. Add the addresses of the deployed relayers to [relayer_addresses.json](./infra/relayer_addresses.json) under the appropriate chain key (e.g., `celo-sepolia`, `monad-testnet`, `polygon-testnet`, `celo`, `monad`)
1. Run `npm run deploy:testnet` and/or `npm run deploy:mainnet` to create GCP cloud scheduler jobs for the new relayers
1. [Add the new relayers to aegis for monitoring](#aegis-export-for-monitoring-relayers)

### Adding a new chain

To add a new chain to an existing environment:

1. Add the chain to `local.environment_chains` in `infra/main.tf`
2. Add its relayer addresses to `infra/relayer_addresses.json` under the chain name
3. Run `npm run deploy:[testnet|mainnet]` — Terraform will create the new function, pub/sub topic, scheduler jobs, and monitoring

### Aegis Export for Monitoring Relayers

1. Run `npm run aegis:export` to print out an aegis config template in your local CLI
1. Copy the relevant sections for the relayers you want to add to aegis
1. Paste them into [aegis' config.yaml](https://github.com/mento-protocol/aegis/blob/main/config.yaml)
1. Run aegis in dev mode via `npm run dev`, check that there are no errors in the log outputs
1. Submit a PR with your changes
1. After successful code review, deploy your changes via `npm run deploy` in aegis
