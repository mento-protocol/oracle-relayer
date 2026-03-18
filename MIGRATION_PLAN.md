# Migration Plan: Consolidate 4 GCP Projects into 2

## Overview

**Current state:** Each chain (celo, celo-sepolia, monad-testnet, monad) has its own GCP project, created via Terraform workspaces. That's 4 GCP projects, each with separate billing, IAM, APIs, service accounts, etc.

**Target state:** 2 GCP projects — `oracle-relayer-testnet` and `oracle-relayer-mainnet` — each hosting multiple cloud functions (one per chain).

| Environment | GCP Project                       | Cloud Functions                             | Pub/Sub Topics                                              |
| ----------- | --------------------------------- | ------------------------------------------- | ----------------------------------------------------------- |
| testnet     | `oracle-relayer-testnet-<random>` | `relay-celo-sepolia`, `relay-monad-testnet` | `relay-testnet-celo-sepolia`, `relay-testnet-monad-testnet` |
| mainnet     | `oracle-relayer-mainnet-<random>` | `relay-celo`, `relay-monad`                 | `relay-mainnet-celo`, `relay-mainnet-monad`                 |

**Migration order:** Testnets first, then mainnet.

---

## Part 1: Code Changes

### 1.1 `infra/main.tf` — New Data Model

The core change: Terraform workspaces shift from chain names to environment names (`testnet` / `mainnet`). Each workspace iterates over its constituent chains via `for_each`.

**Before:**

```hcl
workspace_to_chain_id = {
  "celo"          = "42220"
  "celo-sepolia"  = "11142220"
  "monad-testnet" = "10143"
  "monad"         = "143"
}
```

**After:**

```hcl
locals {
  relayer_addresses = jsondecode(file("${path.module}/relayer_addresses.json"))

  environment_chains = {
    "testnet" = ["celo-sepolia", "monad-testnet"]
    "mainnet" = ["celo", "monad"]
  }

  chains = local.environment_chains[terraform.workspace]

  chain_configs = {
    for chain in local.chains : chain => {
      relayer_addresses = local.relayer_addresses[chain]
      is_production     = terraform.workspace == "mainnet"
    }
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
      }
    }
  ]...)
}
```

The **project-factory module** stays as a single call (one GCP project per workspace):

- `name` = `oracle-relayer-testnet` or `oracle-relayer-mainnet`
- `project_id` = same, with `random_project_id = true`
- `labels` = `{ "environment" = terraform.workspace }`

### 1.2 `infra/cloud-function.tf` — Multiple Functions per Project

| Resource                                      | Change                                                                                                                                                                                                                                             |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `google_cloudfunctions2_function.relay`       | Add `for_each = local.chain_configs`. Name: `relay-${each.key}`. Env vars: `CHAIN = each.key`, `NODE_ENV` based on `each.value.is_production`. Discord secret is shared (per-env). Event trigger references `google_pubsub_topic.relay[each.key]`. |
| `google_cloud_run_service_iam_member.invoker` | Add `for_each = local.chain_configs` (one binding per function).                                                                                                                                                                                   |
| `google_storage_bucket.relay_function`        | Stays singular (shared source bucket). Remove `${terraform.workspace}` from name.                                                                                                                                                                  |
| `google_storage_bucket.logging`               | Stays singular. Remove `${terraform.workspace}` from name.                                                                                                                                                                                         |
| `google_storage_bucket_object.source_code`    | Stays singular (same code, different `CHAIN` env var).                                                                                                                                                                                             |
| `google_project_iam_member.*`                 | Stay singular (project-wide IAM).                                                                                                                                                                                                                  |

### 1.3 `infra/pubsub.tf` — Per-Chain Topics with Environment Prefix

Add `for_each = local.chain_configs` to both resources:

- **Schema name:** `relay-schema-${terraform.workspace}-${each.key}`
  - e.g., `relay-schema-testnet-celo-sepolia`
- **Topic name:** `relay-${terraform.workspace}-${each.key}`
  - e.g., `relay-testnet-celo-sepolia`, `relay-mainnet-monad`

### 1.4 `infra/scheduler.tf` — Flattened Jobs Across Chains

**Before:** `for_each = local.relayer_addresses[terraform.workspace]` (one chain at a time)

**After:** `for_each = local.all_scheduler_jobs` (all chains in the environment, flattened)

- Job name: `request-relay-${each.value.rate_feed_key}-${each.value.chain}`
- Pub/Sub target: `google_pubsub_topic.relay[each.value.chain].id`

### 1.5 `infra/secret-manager.tf` — Simplified

| Secret                | Change                                                                                                                                                                    |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `relayer_mnemonic`    | No change (one per project, shared across functions)                                                                                                                      |
| `discord_webhook_url` | No longer per-chain. One per environment using `local.discord_webhook_url`. Secret ID: `discord-webhook-url-${terraform.workspace}` (e.g., `discord-webhook-url-testnet`) |

### 1.6 `infra/monitoring.tf` — Per-Chain Metrics, Per-Environment Channels

| Resource                                                   | Change                                                                                                                      |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `google_logging_metric.successful_relay_count`             | Add `for_each = local.chain_configs`. Metric name: `successful_relay_count_${each.key}`. Filter by function name per chain. |
| `google_monitoring_notification_channel.discord_channel`   | Stays singular. Uses `local.discord_webhook_url`.                                                                           |
| `google_monitoring_notification_channel.victorops_channel` | Stays singular.                                                                                                             |
| `google_monitoring_alert_policy.successful_relay_policy`   | Add `for_each = local.chain_configs`. One alert per chain.                                                                  |

### 1.7 `infra/variables.tf` — Variable Changes

- **Remove:** `discord_webhook_url_celo`, `discord_webhook_url_celo_sepolia`
- **Add:** `discord_webhook_url_testnet`, `discord_webhook_url_mainnet`
- **Add:** `local_dev_chain` (default: `"celo-sepolia"`) for local `.env` generation

### 1.8 `infra/terraform.tfvars` — Rename Discord Vars

```diff
- discord_webhook_url_celo_sepolia = "https://discord.com/api/webhooks/1280908742..."
- discord_webhook_url_celo = "https://discord.com/api/webhooks/1282681325..."
+ discord_webhook_url_testnet = "https://discord.com/api/webhooks/1280908742..."
+ discord_webhook_url_mainnet = "https://discord.com/api/webhooks/1282681325..."
```

### 1.9 `infra/local-dotenv-file.tf` — Local Dev Chain

Use `var.local_dev_chain` for the `CHAIN` value in the generated `.env` file, since the workspace is now `testnet`/`mainnet` rather than a chain name.

### 1.10 `infra/versions.tf` — No Changes

---

## Part 2: Shell Script & npm Script Changes

### 2.1 `bin/set-up-terraform.sh`

Create workspaces `testnet` and `mainnet` (instead of per-chain). Default to `testnet`.

### 2.2 `bin/get-project-vars.sh`

- Validate workspace as `testnet` or `mainnet` (instead of chain names)
- Accept `--chain <name>` for chain-specific operations (function name, topic name)
- Add helper to derive environment from chain name (`celo-sepolia` → `testnet`, `celo` → `mainnet`)

### 2.3 `bin/deploy-via-gcloud.sh`

Accept chain name, auto-derive environment, select correct workspace, deploy the specific function.

### 2.4 Log & test scripts

Accept chain argument, auto-derive environment, use chain-specific function name within the shared project.

### 2.5 `package.json`

```jsonc
{
  // Workspace switching (environment-level)
  "testnet": "terraform -chdir=infra workspace select testnet && npm run cache:clear",
  "mainnet": "terraform -chdir=infra workspace select mainnet && npm run cache:clear",

  // Deploy all chains in an environment
  "deploy:testnet": "terraform -chdir=infra workspace select -or-create testnet && terraform -chdir=infra apply",
  "deploy:mainnet": "terraform -chdir=infra workspace select -or-create mainnet && terraform -chdir=infra apply",

  // Plan
  "plan:testnet": "terraform -chdir=infra workspace select testnet && terraform -chdir=infra plan",
  "plan:mainnet": "terraform -chdir=infra workspace select mainnet && terraform -chdir=infra plan",

  // Destroy
  "destroy:testnet": "./bin/destroy-project.sh testnet",
  "destroy:mainnet": "./bin/destroy-project.sh mainnet",

  // Per-chain function deploy via gcloud (unchanged interface)
  "deploy:function:celo-sepolia": "./bin/deploy-via-gcloud.sh celo-sepolia",
  "deploy:function:monad-testnet": "./bin/deploy-via-gcloud.sh monad-testnet",
  "deploy:function:celo": "./bin/deploy-via-gcloud.sh celo",
  "deploy:function:monad": "./bin/deploy-via-gcloud.sh monad",
}
```

---

## Part 3: Executing the Migration

### Why Create-New + Destroy-Old (not state import)

- GCP doesn't support moving Cloud Functions between projects
- Relay operations are idempotent — brief overlap where both old and new schedulers fire is harmless
- Much simpler than `terraform import` / `terraform state mv` across different projects
- Natural rollback: if the new project has issues, old projects are still running

---

### Phase 1: Deploy New Testnet Project

After all code changes are merged:

```bash
# 1. Initialize terraform (if not already done)
cd infra
terraform init

# 2. Create the new testnet workspace and deploy
terraform workspace new testnet
terraform plan    # Review the plan — should create 2 functions, 2 topics, 2 schemas, ~40 scheduler jobs, secrets, monitoring
terraform apply   # Deploy the new consolidated testnet project
```

### Phase 2: Verify Testnet

```bash
# 3. Check that functions are deployed
gcloud functions list --project=$(terraform output -raw project_id)

# 4. Check scheduler jobs are running
gcloud scheduler jobs list --project=$(terraform output -raw project_id) --location=europe-west1

# 5. Test each function manually
npm run test:celo-sepolia
npm run test:monad-testnet

# 6. Tail logs to verify relays are succeeding
npm run logs:tail  # (after script updates accept chain arg)

# 7. Let it run for a few hours and monitor for successful relay logs
```

### Phase 3: Tear Down Old Testnet Projects

Once you're confident the new testnet project is working:

```bash
# 8. Pause old scheduler jobs first (prevents duplicate relays during teardown)
#    Do this via GCP Console for each old project, or:
OLD_CELO_SEPOLIA_PROJECT="oracle-relayer-11142220-XXXX"  # get from `gcloud projects list`
OLD_MONAD_TESTNET_PROJECT="oracle-relayer-10143-XXXX"

gcloud scheduler jobs list --project=$OLD_CELO_SEPOLIA_PROJECT --location=europe-west1 \
  --format="value(name)" | xargs -I{} gcloud scheduler jobs pause {} \
  --project=$OLD_CELO_SEPOLIA_PROJECT --location=europe-west1

gcloud scheduler jobs list --project=$OLD_MONAD_TESTNET_PROJECT --location=europe-west1 \
  --format="value(name)" | xargs -I{} gcloud scheduler jobs pause {} \
  --project=$OLD_MONAD_TESTNET_PROJECT --location=europe-west1

# 9. Destroy old projects via terraform (use the OLD workspace state)
#    The old workspace state still exists and references the old resources.
#    You may need to checkout the old code (main branch) to destroy cleanly,
#    since the new code no longer has these workspaces' resource definitions.
git stash  # or work from a separate checkout

terraform workspace select celo-sepolia
terraform destroy

terraform workspace select monad-testnet
terraform destroy

git stash pop  # restore new code

# 10. Delete old workspaces
terraform workspace select testnet
terraform workspace delete celo-sepolia
terraform workspace delete monad-testnet
```

### Phase 4: Deploy New Mainnet Project

```bash
# 11. Create mainnet workspace and deploy
terraform workspace new mainnet
terraform plan    # Review — should create 2 functions (celo, monad), topics, scheduler jobs, etc.
terraform apply
```

### Phase 5: Verify Mainnet

```bash
# 12. Same verification steps as testnet
gcloud functions list --project=$(terraform output -raw project_id)
gcloud scheduler jobs list --project=$(terraform output -raw project_id) --location=europe-west1
npm run test:celo
npm run test:monad

# 13. Monitor for a few hours
```

### Phase 6: Tear Down Old Mainnet Projects

```bash
# 14. Pause old scheduler jobs
OLD_CELO_PROJECT="oracle-relayer-42220-XXXX"
OLD_MONAD_PROJECT="oracle-relayer-143-XXXX"

gcloud scheduler jobs list --project=$OLD_CELO_PROJECT --location=europe-west1 \
  --format="value(name)" | xargs -I{} gcloud scheduler jobs pause {} \
  --project=$OLD_CELO_PROJECT --location=europe-west1

gcloud scheduler jobs list --project=$OLD_MONAD_PROJECT --location=europe-west1 \
  --format="value(name)" | xargs -I{} gcloud scheduler jobs pause {} \
  --project=$OLD_MONAD_PROJECT --location=europe-west1

# 15. Destroy old projects
git stash
terraform workspace select celo
terraform destroy
terraform workspace select monad
terraform destroy
git stash pop

# 16. Delete old workspaces
terraform workspace select mainnet
terraform workspace delete celo
terraform workspace delete monad

# 17. Clean up legacy workspaces (if any exist)
terraform workspace delete default 2>/dev/null || true
terraform workspace delete prod 2>/dev/null || true
terraform workspace delete staging 2>/dev/null || true
terraform workspace delete sepolia 2>/dev/null || true
```

---

## Rollback Plan

At any point before destroying old projects:

1. **Pause new schedulers** in the new project via GCP Console
2. **Resume old schedulers** in the old projects
3. Old projects are fully functional and independent — no data was modified

---

## Summary of All Files to Modify

| File                            | Change                                                                                     |
| ------------------------------- | ------------------------------------------------------------------------------------------ |
| `infra/main.tf`                 | Replace chain-id mapping with environment-to-chains mapping, update project-factory naming |
| `infra/cloud-function.tf`       | Add `for_each` for functions + Cloud Run IAM, simplify bucket naming                       |
| `infra/pubsub.tf`               | Add `for_each` for topics + schemas, include environment in naming                         |
| `infra/scheduler.tf`            | Change `for_each` to flattened `all_scheduler_jobs` map                                    |
| `infra/secret-manager.tf`       | Simplify discord webhook to per-environment                                                |
| `infra/monitoring.tf`           | Add `for_each` for metrics + alerts, keep channels singular                                |
| `infra/local-dotenv-file.tf`    | Use `var.local_dev_chain` for CHAIN value                                                  |
| `infra/variables.tf`            | Add `local_dev_chain`, rename discord webhook vars to per-environment                      |
| `infra/terraform.tfvars`        | Rename discord webhook var names                                                           |
| `bin/get-project-vars.sh`       | Accept environment + chain args, validate testnet/mainnet                                  |
| `bin/deploy-via-gcloud.sh`      | Auto-derive environment from chain argument                                                |
| `bin/set-up-terraform.sh`       | Create testnet/mainnet workspaces                                                          |
| `bin/destroy-project.sh`        | Update to work with environment names                                                      |
| `bin/test-deployed-function.sh` | Accept chain, auto-derive environment                                                      |
| `bin/get-function-logs.sh`      | Accept chain argument                                                                      |
| `bin/tail-function-logs.sh`     | Accept chain argument                                                                      |
| `package.json`                  | Restructure: environment-level deploy/plan/destroy + per-chain function deploy             |
