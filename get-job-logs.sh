#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Load the project variables
source ./set-project-vars.sh

# Fetch raw logs
printf "\n\n"
job_name=request-relay
gcloud logging read "resource.type=cloud_scheduler_job AND resource.labels.job_id=${job_name}" \
	--limit=20 \
	--format="table(timestamp,insertId,jsonPayload.pubsubTopic)"
