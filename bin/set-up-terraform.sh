#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Set up Terraform workspaces and variables
set_up_terraform() {
	script_dir=$(dirname "$0")
	source "${script_dir}/check-gcloud-login.sh"

	if ! command -v terraform &>/dev/null; then
		echo "❌ Error: Terraform is not installed or not in your PATH. Please install terraform: https://developer.hashicorp.com/terraform/install" >&2
		exit 1
	fi

	cd infra
	terraform init
	printf "\n"

	# Function to create a workspace if it does not exist
	create_workspace_if_not_exists() {
		local workspace=$1
		if ! terraform workspace list | grep -q "^[* ] ${workspace}$"; then
			terraform workspace new "${workspace}"
		fi
	}

	create_workspace_if_not_exists "staging"
	printf "\n"
	create_workspace_if_not_exists "prod"

	printf "Switching to staging workspace... "
	terraform workspace select staging
	printf " ✅\n"

	# If we need separate tfvars files for staging and prod, we can create them here.
	# We would then extend our "npm run deploy" scripts to include a -var-file flag:
	#   `terraform apply -var-file="staging.tfvars"`
	# Note that a terraform.tfvars file will always be loaded implicitly, so it can
	# act like a shared file between staging and prod.
	#
	# printf "Creating staging.tfvars and prod.tfvars files..."
	# touch staging.tfvars
	# touch prod.tfvars
	# printf " ✅\n"
}

set_up_terraform
