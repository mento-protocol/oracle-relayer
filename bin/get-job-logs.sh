#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Load the project variables
script_dir=$(dirname "$0")
source "${script_dir}/set-project-vars.sh"

# Fetch raw logs
printf "\n\n"
gcloud logging read "resource.type=cloud_scheduler_job AND resource.labels.job_id=${scheduler_job_name}" \
	--limit=20 \
	--format="table(timestamp,insertId,jsonPayload.pubsubTopic)"
