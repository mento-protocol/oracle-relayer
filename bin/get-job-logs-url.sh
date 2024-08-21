#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Load the project variables
script_dir=$(dirname "$0")
source "${script_dir}/get-project-vars.sh"

usage() {
	printf "\n"
	echo "ℹ️  Usage: $0 <rate-feed-description>"
	echo "  Rate Feed Description: 'PHP/USD' or 'CELO/USD'"
	exit 1
}

# Transform rate feed description to scheduler job name
transform_to_scheduler_id() {
	local rate_feed_description="$1"
	local transformed_name

	# Convert to lowercase and replace '/' with '_'
	transformed_name=$(echo "${rate_feed_description}" | tr '[:upper:]' '[:lower:]' | tr '/' '_')

	# Form the scheduler job name incl. the rate feed description
	echo "request-relay-${transformed_name}-staging"
}

# Validate rate feed description
validate_rate_feed_description() {
	local rate_feed_description="$1"
	if [[ ! ${rate_feed_description} =~ ^[A-Z]{3,4}/[A-Z]{3,4}$ ]]; then
		printf "\n"
		echo "❌ Error: Invalid rate feed description format. Expected format is 'XXX/XXX' or 'XXXX/XXXX' where X is an uppercase letter." >&2
		usage
	fi
}

check_if_job_exists() {
	# Check if the scheduler job exists
	if ! gcloud scheduler jobs describe "${1}" --location "${region}" &>/dev/null; then
		printf "\n"
		echo "❌ Error: Scheduler job '${1}' does not exist in Google Cloud." >&2
		exit 1
	fi
}

get_job_logs_url() {
	# Check if rate feed description argument is provided
	if [[ $# -ne 1 ]]; then
		usage
	fi

	rate_feed_description="$1"
	validate_rate_feed_description "${rate_feed_description}"
	scheduler_job_id=$(transform_to_scheduler_id "${rate_feed_description}")
	check_if_job_exists "${scheduler_job_id}"

	# Generate the URL for the logs
	url="https://console.cloud.google.com/logs/query;query=resource.type%3D%22cloud_scheduler_job%22%20AND%20resource.labels.job_id%3D%22${scheduler_job_id}%22%20AND%20resource.labels.location%3D%22${region}%22?project=${project_id}"
	printf '\n\033[1m%s\033[0m\n' "${url}"

}

get_job_logs_url "$@"
