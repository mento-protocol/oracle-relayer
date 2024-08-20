# Oracle Relayer Infra

- [Local Infra Setup (when project is deployed already)](#local-infra-setup-when-project-is-deployed-already)
- [Debugging Local Problems](#debugging-local-problems)
- [Running and testing the Cloud Function locally](#running-and-testing-the-cloud-function-locally)
- [Testing the Deployed Cloud Function](#testing-the-deployed-cloud-function)
- [Updating the Cloud Function](#updating-the-cloud-function)

## Local Infra Setup (when project is deployed already)

1. Install the `gcloud` CLI

   ```sh
   # For macOS
   brew install google-cloud-sdk

   # For other systems, see https://cloud.google.com/sdk/docs/install
   ```

1. Install trunk (one linter to rule them all)

   ```sh
   # For macOS
   brew install trunk-io

   # For other systems, check https://docs.trunk.io/check/usage
   ```

   Optionally, you can also install the [Trunk VS Code Extension](https://marketplace.visualstudio.com/items?itemName=Trunk.io)

1. Install `jq` (used in a few shell scripts)

   ```sh
   # On macOS
   brew install jq

   # For other systems, see https://jqlang.github.io/jq/
   ```

1. Install Terraform

   ```sh
   # On macOS
   brew tap hashicorp/tap
   brew install hashicorp/tap/terraform

   # For other systems, see https://developer.hashicorp.com/terraform/install
   ```

1. Run terraform setup script

   ```sh
   # This will check required permissions, provision terraform providers, modules, and workspaces
   ./bin/set-up-terraform.sh
   ```

1. Set your local `gcloud` project:

   ```sh
   ./bin/set-project-vars.sh
   ```

1. Create `infra/terraform.tfvars` file. This is like `.env` for Terraform:

   ```sh
   touch infra/terraform.tfvars
   # This file is `.gitignore`d to avoid accidentally leaking sensitive data
   ```

1. Add the following values to your `terraform.tfvars`, you can look up all values in the Google Cloud console (or ask another dev to share his local `terraform.tfvars` with you)

   ```sh
   # Get it via `gcloud organizations list`
   org_id          = "<our-org-id>"

   # Get it via `gcloud billing accounts list` (pick the GmbH account)
   billing_account = "<our-billing-account-id>"

   # Get it via `gcloud secrets versions access latest --secret relayer-private-key-staging`
   # To fetch secrets, you'll need the `Secret Manager Secret Accessor` IAM role assigned to your Google Cloud Account
   relayer_pk      = "<relayer-private-key>"
   ```

## Debugging Local Problems

For most local `terraform` or `gcloud` problems, your first steps should always be to:

- Clear your cache via `npm run cache:clear`
- Re-run the Terraform setup script via `./bin/set-up-terraform.sh`

## Running and testing the Cloud Function locally

- `npm install`
- `npm run dev` to start a local cloud function with hot reload
- `npm test` to call the local cloud function with a mocked `RelayRequested` pubsub event

## Testing the Deployed Cloud Function

You can test the deployed cloud function by manually emitting a pubsub trigger event.

```sh
npm run test:staging
# or npm run test:prod
```

## Updating the Cloud Function

You have two options, using `terraform` or the `gcloud` cli. Both are perfectly fine to use.

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
