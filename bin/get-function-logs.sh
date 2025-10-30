#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Fetches the latest logs for the Cloud Function and displays them in the terminal.
# Usage: get-function-logs.sh [rate_feed]
# Example with rate feed filter: get-function-logs.sh CELO/USD
get_function_logs() {
	# Load the current project variables and spinner utility
	script_dir=$(dirname "$0")
	source "${script_dir}/get-project-vars.sh"
	source "${script_dir}/spinner.sh"

	# Optional rate feed filter (first argument)
	rate_feed="${1-}"

	# Base log query
	query="(resource.labels.service_name=\"${function_name}\")"

	# Add rate feed filter if provided
	if [[ -n ${rate_feed} ]]; then
		query="${query} AND labels.rateFeed=\"${rate_feed}\""
	fi

	# Fetch raw logs with spinner
	printf "\n"

	if [[ -n ${rate_feed} ]]; then
		title=$(printf "Fetching logs for rate feed: \033[1m%s\033[0m\n" "${rate_feed}")
	else
		title="Fetching logs for all rate feeds"
	fi

	start_spinner "${title}"

	# Run the gcloud command
	raw_logs=$(gcloud logging read "${query}" \
		--project "${project_id}" \
		--format json \
		--limit 50)

	# Stop spinner
	cleanup_spinner

	if [[ -n ${rate_feed} ]]; then
		printf "Logs filtered by rate feed: \033[1m%s\033[0m\n" "${rate_feed}"
	fi

	printf "\n"
	# Handle both jsonPayload.message and textPayload formats
	# Extract message handling any format (string or object)
	echo "${raw_logs}" | jq -r 'reverse | .[] |
	  # Determine the message content
	  (if .jsonPayload.message then
	    .jsonPayload.message
	  elif .textPayload then
	    .textPayload
	  elif .jsonPayload then
	    (.jsonPayload | tostring)
	  else
	    ""
	  end) as $message |
	  # Format the output
	  if .severity == "ERROR" then
	    "\u001b[31m[\(.severity)]\u001b[0m \u001b[33m\(.timestamp | sub("T"; " ") | sub("\\..*"; ""))\u001b[0m [\(.labels.rateFeed // "N/A")]: \($message)"
	  else
	    "[\(.severity)] \u001b[33m\(.timestamp | sub("T"; " ") | sub("\\..*"; ""))\u001b[0m [\(.labels.rateFeed // "N/A")]: \($message)"
	  end'
}

get_function_logs "$@"
