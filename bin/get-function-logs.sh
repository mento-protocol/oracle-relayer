#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Fetches the latest logs for the Relay Cloud Function and displays them in the terminal.
# Requires an environment arg (e.g., staging, production).
get_function_logs() {
	# Check if environment parameter is provided
	if [[ $# -ne 1 ]]; then
		echo "Usage: $0 <env>"
		echo "Example: $0 staging"
		exit 1
	fi
	env=$1

	# Get the current Terraform workspace
	current_workspace=$(terraform -chdir=infra workspace show)

	# Select the desired workspace
	terraform -chdir=infra workspace select "${env}"

	# Determine if cache should be invalidated
	invalidate_cache=""
	if [[ ${current_workspace} != "${env}" ]]; then
		invalidate_cache="--invalidate-cache"
	fi

	# Load the project variables
	script_dir=$(dirname "$0")
	source "${script_dir}/get-project-vars.sh" "${invalidate_cache}"

	# Fetch raw logs
	raw_logs=$(gcloud logging read "resource.labels.function_name=${function_name}" \
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
