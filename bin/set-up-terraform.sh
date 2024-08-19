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

	printf "Looking up Terraform Seed Project ID..."
	terraform_seed_project_id=$(awk '/variable "terraform_seed_project_id"/{f=1} f==1&&/default/{print $3; exit}' ./infra/variables.tf | tr -d '",')
	if [[ -z ${terraform_seed_project_id} ]]; then
		echo "❌ Error: Variable \$terraform_seed_project_id is empty. Please ensure it's set in ./infra/variables.tf" >&2
		exit 1
	fi
	printf ' \033[1m%s\033[0m\n' "${terraform_seed_project_id}"

	printf "Looking up Terraform Service Account email..."
	terraform_service_account=$(awk '/variable "terraform_service_account"/{f=1} f==1&&/default/{print $3; exit}' ./infra/variables.tf | tr -d '",')
	if [[ -z ${terraform_service_account} ]]; then
		echo "❌ Error: Variable \$terraform_seed_project_id is empty. Please ensure it's set in ./infra/variables.tf" >&2
		exit 1
	fi
	printf ' \033[1m%s\033[0m\n\n' "${terraform_service_account}"

	# Check if the user has access to the Terraform state via the Service Account Token Creator role
	echo "Checking if you have the Service Account Token Creator role in the terraform seed project..."
	user_account_to_check="user:$(gcloud config get-value account)"
	local check_result
	check_result=$(gcloud projects get-iam-policy "${terraform_seed_project_id}" --format=json |
		jq -r \
			--arg MEMBER "${user_account_to_check}" \
			--arg SA "${terraform_service_account}" \
			'.bindings[] | select(.members[] | contains($MEMBER)) | select(.role == "roles/iam.serviceAccountTokenCreator" or .role == "roles/iam.serviceAccountUser") | .role')

	if echo "${check_result}" | grep -q "roles/iam.serviceAccountTokenCreator"; then
		echo "✅ Permission check passed: ${user_account_to_check} has the Service Account Token Creator role in the terraform seed project."
		printf "\n"
	else
		echo "⚠️ Permission check failed: ${user_account_to_check} does not have the Service Account Token Creator role in the terraform seed project."
		printf "\n"
		echo "Trying to give permission "Service Account Token Creator" role to ${user_account_to_check}"
		if gcloud projects add-iam-policy-binding "${terraform_seed_project_id}" \
			--member="${user_account_to_check}" \
			--role="roles/iam.serviceAccountTokenCreator"; then
			echo "✅ Successfully added the Service Account Token Creator role to ${user_account_to_check}"
		else
			echo "❌ Error: Failed to add the Service Account Token Creator role to ${user_account_to_check}"
			exit 1
		fi
		printf "\n"
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
