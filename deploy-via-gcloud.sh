#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

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
