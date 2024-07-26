#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

printf "Looking up project name in variables.tf..."
project_name=$(awk '/variable "project_name"/{f=1} f==1&&/default/{print $3; exit}' ./infra/variables.tf | tr -d '",')
printf ' \033[1m%s\033[0m\n' "${project_name}"

printf "Fetching the project ID..."
project_id=$(gcloud projects list --filter="name:${project_name}" --format="value(projectId)")
printf ' \033[1m%s\033[0m\n' "${project_id}"

# Set your local default project
printf "Setting your default project to %s..." "${project_id}"
{
	output=$(gcloud config set project "${project_id}" 2>&1 >/dev/null)
	status=$?
}
if [[ ${status} -ne 0 ]]; then
	echo "Error: ${output}"
	exit "${status}"
fi
printf "✅\n"

# Set the quota project to the governance-watchdog project, some gcloud commands require this to be set
printf "Setting the quota project to %s..." "${project_id}"
{
	output=$(gcloud auth application-default set-quota-project "${project_id}" 2>&1 >/dev/null)
	status=$?
}
if [[ ${status} -ne 0 ]]; then
	echo "Error: ${output}"
	exit "${status}"
fi
printf "✅\n"

# Update the project ID in your .env file so your cloud function points to the correct project when running locally
printf "Updating the project ID in your .env file..."
# Check if .env file exists
if [[ ! -f .env ]]; then
	# If .env doesn't exist, create it with the initial value
	echo "GCP_PROJECT_ID=${project_id}" >.env
else
	# If .env exists, perform the sed replacement
	sed -i '' "s/^GCP_PROJECT_ID=.*/GCP_PROJECT_ID=${project_id}/" .env
fi
printf "✅\n\n"

echo "✅ All Done!"
