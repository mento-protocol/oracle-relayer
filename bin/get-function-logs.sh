#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Fetches the latest logs for the Cloud Function and displays them in the terminal.
# Requires an environment arg (e.g., staging, production).
get_function_logs() {
	# Load the current project variables
	script_dir=$(dirname "$0")
	source "${script_dir}/get-project-vars.sh"

	# Fetch raw logs
	raw_logs=$(gcloud logging read "resource.labels.function_name=${function_name}" \
		--project "${project_id}" \
		--format json \
		--limit 50)

	printf "\n"
	echo "${raw_logs}" | jq -r 'reverse | .[] | if .severity == "ERROR" then
  "\u001b[31m[\(.severity)]\u001b[0m \u001b[33m\(.timestamp | sub("T"; " ") | sub("\\..*"; ""))\u001b[0m: \(.jsonPayload.message)"
else
  "[\(.severity)] \u001b[33m\(.timestamp | sub("T"; " ") | sub("\\..*"; ""))\u001b[0m: \(.jsonPayload.message)"
end'
}

get_function_logs "$@"
