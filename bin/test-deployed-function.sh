#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Manually triggers a deployed Cloud Function by emitting a Pubsub event.
# Requires a chain and rate feed ID.
# Usage: test-deployed-function.sh <chain> <rate_feed_description>
# Example: test-deployed-function.sh celo-sepolia PHP/USD
test_deployed_function() {
	# Check if chain and rate feed ID parameters are provided
	if [[ $# -ne 2 ]]; then
		echo "Usage: $0 <chain> <rate_feed_description>"
		echo "Example: $0 celo-sepolia PHP/USD"
		exit 1
	fi
	local chain=$1
	rate_feed_id=$2

	# Validate rate feed ID format
	if ! [[ ${rate_feed_id} =~ ^[A-Z]{3,4}/[A-Z]{3,4}$ ]]; then
		echo "❌ Error: Invalid rate feed ID format. It should be in the form of 'PHP/USD' (3-4 digits per currency symbol)."
		exit 1
	fi

	json_key=$(echo "${rate_feed_id}" | tr '[:upper:]' '[:lower:]' | tr '/' '_')

	# Load the project variables with chain context
	script_dir=$(dirname "$0")
	export CHAIN="${chain}"
	source "${script_dir}/get-project-vars.sh"
	printf "\n"

	# Read the relayer addresses JSON file and extract the address
	json_file="infra/relayer_addresses.json"
	if [[ ! -f ${json_file} ]]; then
		echo "❌ Error: ${json_file} file not found in the script directory."
		exit 1
	fi

	address=$(jq -r ".\"${chain}\".\"${json_key}\"" "${json_file}")

	if [[ ${address} == "null" ]]; then
		echo "❌ Error: Address not found for rate feed ID '${rate_feed_id}' on chain '${chain}'."
		exit 1
	fi

	echo "🌀 Emitting a Pubsub event to trigger the function..."
	printf "\n"
	gcloud pubsub topics publish "${topic_name}" --message="{\"rate_feed_name\": \"${rate_feed_id}\", \"relayer_address\": \"${address}\"}"
	printf "\n"

	echo "✅ Pubsub event emitted!"
	printf "\n"

	echo "Now check the logs via 'npm run logs' or in the Cloud Console."
}

test_deployed_function "$@"
