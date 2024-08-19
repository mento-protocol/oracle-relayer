#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Destroys a Terraform project in a specified workspace.
# Requires an environment arg (e.g., staging, production).
destroy_project() {
	# Helper function to display usage
	usage() {
		echo "Usage: $0 <workspace>"
		echo "  workspace: The Terraform workspace to destroy (e.g., 'staging' or 'prod')"
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

	# Step 2: Run terraform destroy
	echo "Running terraform destroy..."
	terraform destroy
	printf "\n\n"
	# If we add separate variable files for each workspace, we would change this to:
	# terraform destroy -var-file="${workspace}.tfvars"

	echo "🏁 Terraform project in workspace ${workspace}' has been destroyed and cleaned up."

}

destroy_project "$@"
