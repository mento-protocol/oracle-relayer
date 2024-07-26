# Oracle Relayer Infra

## Install

1. [Ensure Billing is enabled for the GCP project](https://cloud.google.com/billing/docs/how-to/verify-billing-enabled#confirm_billing_is_enabled_on_a_project)
1. Install terraform locally (i.e. `brew update && brew install terraform`)
1. Authenticate with Google Cloud in your local shell via `gcloud auth application-default login`
1. Run `terraform plan` to see if your local setup is working

### Google Cloud APIs

- Pub/Sub API
- Service Usage API <https://console.cloud.google.com/apis/api/serviceusage.googleapis.com/metrics?project=oracle-relayer>

You must have the following Google Cloud IAM roles to deploy this project via Terraform:

- `roles/resourcemanager.folderViewer` on the folder that you want to create the project in
- `roles/resourcemanager.organizationViewer` on the organization
- `roles/resourcemanager.projectCreator` on the organization
- `roles/billing.user` on the organization
- `roles/storage.admin` on `bucket_project`

### Security Tooling

- `brew install tflint`
- `brew install terrascan`
- `brew install pipx && pipx ensurepath && pipx install checkov`
