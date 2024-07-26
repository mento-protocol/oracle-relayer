#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Load the project variables
source ./set-project-vars.sh

# TODO: Load this dynamically maybe via `gcloud scheduler jobs list`
job_name=request-relay
url="https://console.cloud.google.com/logs/query;query=resource.type%3D%22cloud_scheduler_job%22%20AND%20resource.labels.job_id%3D%22${job_name}%22%20AND%20resource.labels.location%3D%22${region}%22"
printf '\n\033[1m%s\033[0m\n' "${url}"
