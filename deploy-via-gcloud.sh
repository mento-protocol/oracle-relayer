#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Check if environment parameter is provided
if [[ $# -ne 1 ]]; then
	echo "Usage: $0 <env>"
	echo "Example: $0 staging"
	exit 1
fi
env=$1

# Select the correct environment
terraform -chdir=infra workspace select "${env}"

# Load the project variables
source ./set-project-vars.sh

echo "Deploying to Google Cloud Functions..."
gcloud functions deploy "${function_name}" \
	--entry-point "${function_entry_point}" \
	--gen2 \
	--project "${project_id}" \
	--region "${region}" \
	--runtime nodejs20 \
	--service-account "${service_account_email}" \
	--source . \
	--trigger-topic "${topic_name}"

echo "✅ All Done!"
