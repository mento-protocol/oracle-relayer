#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Load the project variables
script_dir=$(dirname "$0")
source "${script_dir}/get-project-vars.sh"

url="https://console.cloud.google.com/logs/query;query=resource.type%3D%22cloud_scheduler_job%22%20AND%20resource.labels.job_id%3D%22${scheduler_job_name}%22%20AND%20resource.labels.location%3D%22${region}%22?project=${project_id}"
printf '\n\033[1m%s\033[0m\n' "${url}"
