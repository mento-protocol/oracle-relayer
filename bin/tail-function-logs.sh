#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Tails the logs for the Cloud Function in real-time.
# Usage: tail-function-logs.sh [rate_feed]
# Example with rate feed filter: tail-function-logs.sh CELO/USD
tail_function_logs() {
	# Load the current project variables
	script_dir=$(dirname "$0")
	source "${script_dir}/get-project-vars.sh"

	# Optional rate feed filter (first argument)
	rate_feed="${1-}"

	# Base log query
	query="(resource.labels.service_name=\"${function_name}\")"

	# Add rate feed filter if provided
	if [[ -n ${rate_feed} ]]; then
		query="${query} AND labels.rateFeed=\"${rate_feed}\""
		printf "\nTailing logs for rate feed: \033[1m%s\033[0m\n\n" "${rate_feed}"
	else
		printf "\nTailing all logs for \033[1m%s\033[0m\n\n" "${function_name}"
	fi

	# Tail logs in real-time with formatted output
	# Parse YAML with compact awk script
	gcloud beta logging tail "${query}" \
		--project "${project_id}" \
		--format "default" 2>&1 |
		grep --line-buffered -v -E "(UserWarning|pkg_resources|Initializing tail session)" |
		awk -v y="\033[33m" -v r="\033[31m" -v x="\033[0m" '
		/^timestamp:/ { t=$2; gsub(/['\''T]/, " ", t); gsub(/\.[0-9]+Z/, "", t) }
		/^severity:/ { s=($2=="500"||$2=="ERROR")?"ERROR":($2=="400"||$2=="WARNING")?"WARNING":"INFO" }
		/^  rateFeed:/ { f=$2 }
		/^  message:/ { sub(/^  message: '\''?/, ""); sub(/'\''$/, ""); m=$0 }
		/^text_payload:/ { sub(/^text_payload: '\''?/, ""); sub(/'\''$/, ""); m=$0 }
		/^---$/ && t && m {
			printf "%s%s%s [%s] [%s]: %s\n", y, t, x, s, (f?f:"N/A"), m; fflush()
			t=s=f=m=""
		}'
}

tail_function_logs "$@"
