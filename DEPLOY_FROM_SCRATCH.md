# Deployment from scratch

How to deploy the entire off-chain oracle relayer infrastructure from scratch.

## Infra Deployment via Terraform

### Terraform State Management

- The Terraform State for this project lives in our shared Terraform Seed Project with the ID `mento-terraform-seed-ffac`
- Deploying the relayer project for the first time should automatically create a subfolder in the google storage bucket used for terraform state management in the seed project

### Google Cloud Permission Requirements

You must have the following Google Cloud IAM roles to deploy this project via Terraform:

- `roles/resourcemanager.folderViewer` on the folder that you want to create the project in
- `roles/resourcemanager.organizationViewer` on the organization
- `roles/resourcemanager.projectCreator` on the organization
- `roles/billing.user` on the organization
- `roles/storage.admin` to allow creation of new storage buckets
- `roles/iam.serviceAccountTokenCreator` on our Terraform Seed Project to allow impersonating our shared terraform service account

### Deployment

1. Run `./bin/set-up-terraform.sh` to check required permissions and provision all required terraform providers, modules, and workspaces

1. **Deploy the project to staging via `npm run deploy:staging`** (which uses `terraform apply`)

   - You will see an overview of all resources to be created. Review them if you like and then type "Yes" to confirm.
   - This command can take up to 10 minutes because it does a lot of work creating and configuring all defined Google Cloud Resources
   - ❌ Given the complexity of setting up an entire Google Cloud Project incl. service accounts, permissions, etc., you might run
     into deployment errors with some components.

     **Often a simple retry of `terraform apply` helps**. Sometimes a dependency of a resource has simply not finished creating when
     terraform already tried to deploy the next one, so waiting a few minutes for things to settle can help.

1. Set your local `gcloud` context to the correct project, region etc.

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

1. **Now deploy the project to production via `npm run deploy:prod`** (which uses `terraform apply`)

1. Update your local `gcloud` context to production via `./bin/get-project-vars.sh` again

1. And check this also worked via `npm run logs:prod`

## Debugging Problems

### View Logs

For most problems, you'll likely want to check the cloud function logs first.

- `npm run logs` will print the latest 50 staging log entries into your local terminal for quick and easy access
- `npm run logs:url` will print the URL to the staging function logs in the Google Cloud Console for full access

## Teardown

Note: You might run into permission issues here, especially around deleting the associated billing account resources. I didn't have time to figure out the minimum set of permissions required to delete this project so the easiest would be to let an organization owner (i.e. Bogdan) run this with full permissions if you face any issues.

1. Run `npm run destroy:staging` to delete the entire staging environment from google cloud
1. Run `npm run destroy:prod` to delete the entire production environment from google cloud
