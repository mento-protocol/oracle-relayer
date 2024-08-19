#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Manually triggers a deployed Cloud Function by emitting a Pubsub event.
# Requires an environment arg (e.g., staging, production).
test_deployed_function() {
	# Check if environment parameter is provided
	if [[ $# -ne 1 ]]; then
		echo "Usage: $0 <env>"
		echo "Example: $0 staging"
		exit 1
	fi
	env=$1

	terraform -chdir=infra workspace select "${env}"

	# Load the project variables
	script_dir=$(dirname "$0")
	source "${script_dir}/get-project-vars.sh"

	echo "🌀 Emitting a Pubsub event to trigger the function..."
	printf "\n"
	# TODO: Update the relayer address to a real one once we have one deployed in prod
	gcloud pubsub topics publish "${topic_name}" --message='{"rate_feed_name": "TEST/USD", "relayer_address": "0x13374935239dacdecf7c5ba76d8de40b077b7420"}'
	printf "\n"

	echo "✅ Pubsub event emitted!"
	printf "\n"

	logs_url=$(npm run logs:url 2>/dev/null | tail -n1 || echo "npm run logs:url")
	echo "Now check the logs via \`npm run logs\` or in the Cloud Console via ${logs_url}"
}

test_deployed_function "$@"
