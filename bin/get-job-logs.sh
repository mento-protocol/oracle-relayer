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
	echo "${scheduler_job_name}-${transformed_name}-${workspace}"
}

# Validate rate feed description
validate_rate_feed_description() {
	local rate_feed_description="$1"
	if [[ ! ${rate_feed_description} =~ ^[A-Z]{3,4}/[A-Z]{3,4}$ ]]; then
		printf "\n"
		echo "❌ Error: Invalid rate feed description format. Expected format is 'XXX/XXX' where X is an uppercase letter." >&2
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

# Check if workspace argument is provided
if [[ $# -ne 1 ]]; then
	usage
fi

rate_feed_description="$1"
validate_rate_feed_description "${rate_feed_description}"
scheduler_job_id=$(transform_to_scheduler_id "${rate_feed_description}")
check_if_job_exists "${scheduler_job_id}"

# Fetch raw logs
printf "\n\n"
gcloud logging read "resource.type=cloud_scheduler_job AND resource.labels.job_id=${scheduler_job_id}" \
	--limit=20 \
	--format="table(timestamp,insertId,jsonPayload.pubsubTopic)"
