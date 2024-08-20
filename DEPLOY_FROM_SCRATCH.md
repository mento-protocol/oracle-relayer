# Deployment from scratch

## Infra Deployment via Terraform

### Google Cloud Permission Requirements

You must have the following Google Cloud IAM roles to deploy this project via Terraform:

- `roles/resourcemanager.folderViewer` on the folder that you want to create the project in
- `roles/resourcemanager.organizationViewer` on the organization
- `roles/resourcemanager.projectCreator` on the organization
- `roles/billing.user` on the organization
- `roles/storage.admin` on `bucket_project`

### Deployment

1. Outcomment the `backend` section in `main.tf` (because this bucket doesn't exist yet, it will be created by the first `terraform apply` run)

   ```hcl
   # backend "gcs" {
   #   bucket = "terraform-state-<random-suffix>"
   # }
   ```

1. Run `terraform init` to install the required providers and init a temporary local backend in a `terraform.tfstate` file

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
   ./bin/get-project-vars.sh
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
   terraform state show "module.oracle_relayer.module.project-factory.google_storage_bucket.project_bucket[0]" | grep name | awk -F '"' '{print $2}' | pbcopy
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

## TODO: document these better

- `./set-up-terraform.sh`
- Hard requirement on seed project
- State bucket
