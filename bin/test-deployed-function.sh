#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Manually triggers a deployed Cloud Function by emitting a Pubsub event.
# Requires an environment arg (e.g., staging, production).
test_deployed_function() {
	# Check if environment and rate feed ID parameters are provided
	if [[ $# -ne 2 ]]; then
		echo "Usage: $0 <env> <rate_feed_id>"
		echo "Example: $0 staging PHP/USD"
		exit 1
	fi
	env=$1
	rate_feed_id=$2

	# Validate rate feed ID format
	if ! [[ ${rate_feed_id} =~ ^[A-Z]{3,4}/[A-Z]{3,4}$ ]]; then
		echo "❌ Error: Invalid rate feed ID format. It should be in the form of 'PHP/USD' (3-4 digits per currency symbol)."
		exit 1
	fi

	json_key=$(echo "${rate_feed_id}" | tr '[:upper:]' '[:lower:]' | tr '/' '_')

	terraform -chdir=infra workspace select "${env}"

	# Load the project variables
	script_dir=$(dirname "$0")
	source "${script_dir}/get-project-vars.sh"
	printf "\n"

	# Read the relayer addresses JSON file and extract the address
	json_file="infra/relayer_addresses.json"
	if [[ ! -f ${json_file} ]]; then
		echo "❌ Error: ${json_file} file not found in the script directory."
		exit 1
	fi

	address=$(jq -r ".${env}.\"${json_key}\"" "${json_file}")

	if [[ ${address} == "null" ]]; then
		echo "❌ Error: Address not found for rate feed ID '${rate_feed_id}' in environment '${env}'."
		exit 1
	fi

	echo "🌀 Emitting a Pubsub event to trigger the function..."
	printf "\n"
	gcloud pubsub topics publish "${topic_name}" --message='{"rate_feed_name": "PHP/USD", "relayer_address": "0xF93c6fe760F09f19880f57D643a17A515c11165c"}'
	printf "\n"

	echo "✅ Pubsub event emitted!"
	printf "\n"

	logs_url=$(npm run logs:url 2>/dev/null | tail -n1 || echo "npm run logs:url")
	echo "Now check the logs via \`npm run logs\` or in the Cloud Console via ${logs_url}"
}

test_deployed_function "$@"
