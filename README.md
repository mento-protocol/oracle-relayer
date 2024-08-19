# Oracle Relayer Infra

## Requirements for local development

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

1. Install Terraform

   ```sh
   # On macOS
   brew tap hashicorp/tap
   brew install hashicorp/tap/terraform

   # For other systems, see https://developer.hashicorp.com/terraform/install
   ```

1. Install `jq` (used in a few shell scripts)

   ```sh
   # On macOS
   brew install jq

   # For other systems, see https://jqlang.github.io/jq/
   ```

1. Authenticate with Google Cloud default credentials in your local shell

   ```sh
   gcloud auth application-default login
   ```

   The key differences between `gcloud auth login` and `gcloud auth application-default login` are:

   1. `gcloud auth login` authenticates you for general gcloud CLI use and interactive scenarios.
   2. `gcloud auth application-default login` sets up Application Default Credentials (ADC) for use by local development environments and applications, such as running our function locally via `npm start`
   3. ADC credentials are specifically intended for [Google Auth Library](https://www.npmjs.com/package/google-auth-library) access, while regular login is for broader gcloud command usage.

1. To fetch the secrets used by this function from Secret Manager, you'll need the `Secret Manager Secret Accessor` IAM role assigned to your Google Cloud Account

## Local Infra Setup (when project is deployed already)

1. Set your local `gcloud` project to the watchdog project:

   ```sh
   ./set-project-vars.sh
   ```

1. Inside the `./infra` folder, run `terraform init` to install all required terraform providers and sync the terraform state from the project's google cloud storage bucket:

   ```sh
   cd infra
   terraform init
   ```

1. While inside the `infra` folder, create `terraform.tfvars` file. This is like `.env` for Terraform:

   ```sh
   touch terraform.tfvars
   # This file is `.gitignore`d to avoid accidentally leaking sensitive data
   ```

1. Add the following values to your `terraform.tfvars`, you can look up all values in the Google Cloud console (or ask another dev to share his local `terraform.tfvars` with you)

   ```sh
   # Get it via `gcloud organizations list`
   org_id               = "<our-org-id>"

   # Get it via `gcloud billing accounts list` (pick the GmbH account)
   billing_account      = "<our-billing-account-id>"
   ```

1. Add the relayer account private key from Google Cloud Secret Manager to your local `terraform.tfvars`:

   ```sh
   # You need the "Secret Manager Secret Accessor" IAM role for this command to succeed
   echo "\nrelayer_pk = \"$(gcloud secrets versions access latest --secret relayer-private-key)\"" >> terraform.tfvars
   ```

1. Auto-generate a local `.env` file by running `npm run generate:env`

## Running and testing the Cloud Function locally

- `npm install`
- `npm start` to start a local cloud function
- `npm test` to call the local cloud function with a mocked `RelayRequested` pubsub event

## Testing the Deployed Cloud Function

You can test the deployed cloud function by manually emitting a pubsub trigger event.

```sh
npm run test:prod
```

## Updating the Cloud Function

You have two options, using `terraform` or the `gcloud` cli. Both are perfectly fine to use.

1. Via `terraform` by running `npm run deploy:via:tf`
   - How? The npm task will:
     - Call `terraform apply` which re-deploys the function with the latest code from your local machine
   - Pros
     - Keeps the terraform state clean
     - Same command for all changes, regardless of infra or cloud function code
   - Cons
     - Less familiar way of deploying cloud functions (if you're used to `gcloud functions deploy`)
     - Less log output
     - Slightly slower because `terraform apply` will always fetch the current state from the cloud storage bucket before deploying
2. Via `gcloud` by running `npm run deploy:via:gcloud`
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

## Infra Deployment via Terraform

### Google Cloud Permission Requirements

You must have the following Google Cloud IAM roles to deploy this project via Terraform:

- `roles/resourcemanager.folderViewer` on the folder that you want to create the project in
- `roles/resourcemanager.organizationViewer` on the organization
- `roles/resourcemanager.projectCreator` on the organization
- `roles/billing.user` on the organization
- `roles/storage.admin` on `bucket_project`

### Deployment from scratch

1. Outcomment the `backend` section in `main.tf` (because this bucket doesn't exist yet, it will be created by the first `terraform apply` run)

   ```hcl
   # backend "gcs" {
   #   bucket = "terraform-state-<random-suffix>"
   # }
   ```

1. Run `terraform init` to install the required providers and init a temporary local backend in a `terraform.tfstate` file

1. Add the relayer account private key to your local `terraform.tfvars`. You can either get the existing one by searching for `Oracle Relayer` inside the shared Eng. folder on LastPass, or generate a new one if you wish to rotate the account

   ```sh
   # This will be stored in Google Secret Manager upon deployment via Terraform
   echo "relayer_pk = \"<relayer_pk>\"" >> terraform.tfvars
   ```

1. **Deploy the entire project via `terraform apply`**

   - You will see an overview of all resources to be created. Review them if you like and then type "Yes" to confirm.
   - This command can take up to 10 minutes because it does a lot of work creating and configuring all defined Google Cloud Resources
   - ❌ Given the complexity of setting up an entire Google Cloud Project incl. service accounts, permissions, etc., you might run
     into deployment errors with some components.

     **Often a simple retry of `terraform apply` helps**. Sometimes a dependency of a resource has simply not finished creating when
     terraform already tried to deploy the next one, so waiting a few minutes for things to settle can help.

1. Set your local `gcloud` project ID to our freshly created one:

   ```sh
   # This script will also cache some gcloud values into a local file which speeds up tasks like `npm run logs`
   ./set-project-vars.sh
   ```

1. Check that everything worked as expected

   ```sh
   # Check that the function is up and receiving events by checking the logs
   npm run logs

   # If you prefer the cloud console:
   npm run logs:url
   ```

### Migrate Terraform State to Google Cloud

For all team members to be able to manage the Google Cloud infrastructure, you need to migrate the terraform state from your local backend (`terraform.tfstate`) to a remote backend in a Google Cloud Storage Bucket:

1. Copy the name of the created terraform state bucket to your clipboard:

   ```sh
   terraform state show "module.project-factory.module.project-factory.google_storage_bucket.project_bucket[0]" | grep name | awk -F '"' '{print $2}' | pbcopy
   ```

1. Uncomment the original `backend` section in `main.tf` and replace the bucket name with the new one you just copied

   ```hcl
   backend "gcs" {
     bucket = "terraform-state-<random-suffix>"
   }
   ```

1. Complete the state migration:

   ```sh
   terraform init -migrate-state

   # This command will ask you _"Do you want to copy existing state to the new backend?"_ — Make sure to type **YES** here to not re-create everything from scratch again
   ```

1. Commit & push your changes

   ```sh
   git commit -m "build: updated terraform remote backend to new google cloud storage bucket"
   git push
   ```

1. Delete your local backend files, you don't need them anymore because our state now lives in the cloud and can be shared amongst team members:

   ```sh
   rm terraform.tfstate
   rm terraform.tfstate.backup
   ```

## Debugging Problems

### View Logs

For most problems, you'll likely want to check the cloud function logs first.

- `npm run logs` will print the latest 50 log entries into your local terminal for quick and easy access
- `npm run logs:url` will print the URL to the function logs in the Google Cloud Console for full access

## Teardown

Before destroying the project, you'll need to migrate the terraform state from the cloud bucket backend onto your local machine.
Because `terraform destroy` will also destroy the bucket that the terraform state is stored in so the moment the bucket gets
destroyed, the terraform state will be gone and the destroy command will fail and the project deletion might not succeed.

1. Outcomment the `backend` section in `main.tf` again

   ```hcl
   # backend "gcs" {
   #   bucket = "terraform-state-<random-suffix>"
   # }
   ```

1. Run `terraform init -migrate-state` to move the state into a local `terraform.tfstate` file

1. Now run `terraform destroy` to delete all cloud resources associated with this project
   - You might run into permission issues here, especially around deleting the associated billing account resources
   - I didn't have time to figure out the minimum set of permissions required to delete this project so the easiest would be to let an organization owner (i.e. Bogdan) run this with full permissions
