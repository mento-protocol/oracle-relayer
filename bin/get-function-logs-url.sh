#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Prints the log explorer URL for a Cloud Function and displays it in the terminal.
# Usage: get-function-logs-url.sh <chain> [rate_feed]
# Example: get-function-logs-url.sh celo-sepolia
# Example with rate feed filter: get-function-logs-url.sh celo-sepolia CELO/USD
get_function_logs_url() {
	if [[ $# -lt 1 ]]; then
		echo "Usage: $0 <chain> [rate_feed]"
		echo "Example: $0 celo-sepolia CELO/USD"
		exit 1
	fi

	local chain=$1
	shift

	# Load the current project variables with chain context
	script_dir=$(dirname "$0")
	export CHAIN="${chain}"
	source "${script_dir}/get-project-vars.sh"

	# Optional rate feed filter (next argument)
	rate_feed="${1-}"

	# URL-encode the rate feed (replace / with %2F)
	rate_feed_encoded=$(echo "${rate_feed}" | sed 's/\//%2F/g')

	# Get time 1 hour ago in UTC
	start_time=$(date -u -v-1H +"%Y-%m-%dT%H:%M:%S.000Z")

	# Get current time in UTC
	end_time=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

	# Build the query with optional rate feed filter
	if [[ -n ${rate_feed} ]]; then
		logs_explorer_url=$(
			cat <<EOF | tr -d '\n' | sed 's/[[:space:]]//g'
https://console.cloud.google.com/logs/query;query=resource.labels.service_name%20%3D%20%22${function_name}%22%20AND%20labels.rateFeed%20%3D%20%22${rate_feed_encoded}%22;summaryFields=labels%252FrateFeed,labels%252Fchain:false:32:beginning;startTime=${start_time};endTime=${end_time}?project=${project_id}
EOF
		)
		printf '\n\033[1mLogs Explorer URL (filtered by %s)\033[0m\n%s\n' "${rate_feed}" "${logs_explorer_url}"
	else
		logs_explorer_url=$(
			cat <<EOF | tr -d '\n' | sed 's/[[:space:]]//g'
https://console.cloud.google.com/logs/query;query=resource.labels.service_name%20%3D%20%22${function_name}%22;storageScope=project;summaryFields=labels%252FrateFeed,labels%252Fchain:false:32:beginning;startTime=${start_time};endTime=${end_time}?project=${project_id}
EOF
		)
		printf '\n\033[1mLogs Explorer URL\033[0m - Your function logs in the GCP Logs Explorer, usually this is what you want.\n%s\n' "${logs_explorer_url}"
	fi

	echo ""

	cloud_run_logs_url="https://console.cloud.google.com/run/detail/${region}/${function_name}/logs?project=${project_id}"
	printf '\n\033[1mCloud Run Logs\033[0m - The underlying Cloud Run logs, mainly for problems occurring during startup of the function.\n%s\n' "${cloud_run_logs_url}"
}

get_function_logs_url "$@"
