#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Destroys a Terraform project in a specified workspace.
# Requires an environment arg (e.g., celo-sepolia, celo).
destroy_project() {
	# Helper function to display usage
	usage() {
		echo "Usage: $0 <workspace>"
		echo "  workspace: The Terraform workspace to destroy (e.g., 'celo-sepolia' or 'celo')"
		exit 1
	}

	# Check if workspace argument is provided
	if [[ $# -ne 1 ]]; then
		usage
	fi

	workspace=$1

	# The file containing the terraform backend
	file="versions.tf"

	# Step 0: Cd into the infra directory and check if the file exists
	cd infra
	if [[ ! -f ${file} ]]; then
		echo "Error: File ${file} does not exist."
		exit 1
	fi

	# Step 1: Select the workspace to destroy
	echo "Selecting workspace: ${workspace}..."
	terraform workspace select "${workspace}"
	printf "\n\n"

	# Step 2: Capture the project ID before destroying (for cleanup)
	echo "Capturing project ID for cleanup..."
	project_id=$(terraform output -raw project_id 2>/dev/null || echo "")
	if [[ -n ${project_id} ]]; then
		echo "Project ID to clean up: ${project_id}"
	fi
	printf "\n\n"

	# Step 3: Run terraform destroy
	echo "Running terraform destroy..."
	terraform destroy
	printf "\n\n"
	# If we add separate variable files for each workspace, we would change this to:
	# terraform destroy -var-file="${workspace}.tfvars"

	# Step 4: Clean up local Terraform cache
	echo "Cleaning up local Terraform cache..."
	if [[ -d .terraform ]]; then
		rm -rf .terraform
		echo "✓ Removed .terraform directory"
	fi
	printf "\n\n"

	# Step 5: Clean up gcloud configuration if it references the destroyed project
	if [[ -n ${project_id} ]]; then
		echo "Checking gcloud configuration..."
		current_project=$(gcloud config get-value project 2>/dev/null || echo "")
		if [[ ${current_project} == "${project_id}" ]]; then
			gcloud config unset project
			echo "✓ Unset gcloud project (was referencing destroyed project)"
		else
			echo "✓ gcloud project config is clean"
		fi
		printf "\n\n"

		# Step 6: Clean up Application Default Credentials if they reference the destroyed project
		echo "Checking Application Default Credentials..."
		adc_file="${HOME}/.config/gcloud/application_default_credentials.json"
		if [[ -f ${adc_file} ]]; then
			quota_project=$(grep -o '"quota_project_id":[[:space:]]*"[^"]*"' "${adc_file}" | sed 's/"quota_project_id":[[:space:]]*"\([^"]*\)"/\1/')
			if [[ ${quota_project} == "${project_id}" ]]; then
				# Remove the quota_project_id line from the JSON file
				if [[ ${OSTYPE} == "darwin"* ]]; then
					# macOS sed syntax
					sed -i '' '/"quota_project_id":/d' "${adc_file}"
				else
					# Linux sed syntax
					sed -i '/"quota_project_id":/d' "${adc_file}"
				fi
				echo "✓ Removed quota_project_id from Application Default Credentials"
			else
				echo "✓ Application Default Credentials are clean"
			fi
		else
			echo "✓ No Application Default Credentials file found"
		fi
		printf "\n\n"
	fi

	echo "🏁 Terraform project in workspace '${workspace}' has been destroyed and cleaned up."

}

destroy_project "$@"
