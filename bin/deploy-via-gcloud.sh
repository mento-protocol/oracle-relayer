#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Deploys a Cloud Function for a specific chain using gcloud.
# Usage: deploy-via-gcloud.sh <chain>
# Example: deploy-via-gcloud.sh celo-sepolia
deploy_via_gcloud() {
	if [[ $# -ne 1 ]]; then
		echo "Usage: $0 <chain>"
		echo "  chain: The chain to deploy (e.g., 'celo-sepolia', 'monad-testnet', 'polygon-testnet', 'celo', 'monad')"
		exit 1
	fi

	local chain=$1
	printf "\n"

	# Load the current project variables
	script_dir=$(dirname "$0")
	export CHAIN="${chain}"
	source "${script_dir}/get-project-vars.sh"

	# Deploy the Google Cloud Function
	echo "Deploying relay-${chain} to Google Cloud Functions..."
	gcloud functions deploy "${function_name}" \
		--entry-point "${function_entry_point}" \
		--gen2 \
		--project "${project_id}" \
		--region "${region}" \
		--runtime nodejs22 \
		--service-account "${service_account_email}" \
		--source . \
		--trigger-topic "${topic_name}"

	echo "✅ All Done!"
}

deploy_via_gcloud "$@"
