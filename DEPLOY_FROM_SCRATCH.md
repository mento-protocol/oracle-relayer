# Deployment from scratch

How to deploy the entire off-chain oracle relayer infrastructure from scratch.

- [Infra Deployment via Terraform](#infra-deployment-via-terraform)
  - [Terraform State Management](#terraform-state-management)
  - [Google Cloud Permission Requirements](#google-cloud-permission-requirements)
    - [Using Service Account Impersonation (recommended)](#using-service-account-impersonation-recommended)
    - [Using Your Own Gcloud User Account (not recommended)](#using-your-own-gcloud-user-account-not-recommended)
  - [Deployment](#deployment)
- [Debugging Problems](#debugging-problems)
  - [View Logs](#view-logs)
- [Teardown](#teardown)

## Infra Deployment via Terraform

### Terraform State Management

- The Terraform State for this project lives in our shared Terraform Seed Project with the ID `mento-terraform-seed-ffac`
- Deploying the project for the first time should automatically create a subfolder in the [google storage bucket used for terraform state management in the seed project](https://console.cloud.google.com/storage/browser/mento-terraform-tfstate-6ed6;tab=objects?forceOnBucketsSortingFiltering=true&project=mento-terraform-seed-ffac&prefix=&forceOnObjectsSortingFiltering=false)
- There are 2 Terraform workspaces: `testnet` and `mainnet`, each managing a single GCP project that hosts multiple cloud functions (one per chain)

### Google Cloud Permission Requirements

#### Using Service Account Impersonation (recommended)

The project is preconfigured to impersonate our shared terraform service account (see [`./infra/versions.tf`](./infra/versions.tf)).
The only permission you will need on your own gcloud user account is `roles/iam.serviceAccountTokenCreator` to allow you to impersonate our shared terraform service account.

#### Using Your Own Gcloud User Account (not recommended)

If for whatever reason service account impersonation doesn't work, you'll need at least the following permissions on your personal gcloud account to deploy this project with terraform:

- `roles/resourcemanager.folderViewer` on the folder that you want to create the project in
- `roles/resourcemanager.organizationViewer` on the organization
- `roles/resourcemanager.projectCreator` on the organization
- `roles/billing.user` on the organization
- `roles/storage.admin` to allow creation of new storage buckets

### Deployment

1. Run `./bin/set-up-terraform.sh` to check required permissions and provision all required terraform providers, modules, and workspaces

1. **Deploy the testnet project via `npm run deploy:testnet`** (which uses `terraform apply`)

   - This will create a single GCP project (`oracle-relayer-testnet`) with cloud functions for all testnet chains (celo-sepolia, monad-testnet)
   - You will see an overview of all resources to be created. Review them if you like and then type "Yes" to confirm.
   - This command can take up to 10 minutes because it does a lot of work creating and configuring all defined Google Cloud Resources
   - Given the complexity of setting up an entire Google Cloud Project incl. service accounts, permissions, etc., you might run
     into deployment errors with some components.

     **Often a simple retry of `terraform apply` helps**. Sometimes a dependency of a resource has simply not finished creating when
     terraform already tried to deploy the next one, so waiting a few minutes for things to settle can help.

1. Set your local `gcloud` context to the correct project, region etc.

   ```sh
   # This script will also cache some gcloud values into a local file which speeds up tasks like log viewing
   npm run cache:clear
   ```

1. Check that everything worked as expected

   ```sh
   # Check that the functions are up and receiving events by checking the logs
   npm run logs:celo-sepolia
   npm run logs:monad-testnet

   # If you prefer the cloud console:
   npm run logs:url:celo-sepolia
   ```

1. **Now deploy the mainnet project via `npm run deploy:mainnet`** (which uses `terraform apply`)

   - This creates `oracle-relayer-mainnet` with cloud functions for celo and monad

1. Update your local `gcloud` context to mainnet via `npm run mainnet`

1. And verify via:

   ```sh
   npm run logs:celo
   npm run logs:monad
   ```

## Debugging Problems

### View Logs

For most problems, you'll likely want to check the cloud function logs first.

- `npm run logs:<chain>` will print the latest 50 log entries into your local terminal for quick and easy access (e.g., `npm run logs:celo-sepolia`)
- `npm run logs:url:<chain>` will print the URL to the function logs in the Google Cloud Console for full access

## Teardown

Note: You might run into permission issues here, especially around deleting the associated billing account resources. I didn't have time to figure out the minimum set of permissions required to delete this project so the easiest would be to let an organization owner (i.e. Bogdan) run this with full permissions if you face any issues.

1. Run `npm run destroy:testnet` to delete the entire testnet environment from Google Cloud
1. Run `npm run destroy:mainnet` to delete the entire mainnet environment from Google Cloud
