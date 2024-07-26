#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Load the project variables
source ./set-project-vars.sh

# Fetch raw logs
raw_logs=$(gcloud functions logs read "${function_name}" \
	--region "${region}" \
	--format json \
	--limit 50 \
	--sort-by TIME_UTC)

# Format logs
printf "\n\n"
echo "${raw_logs}" | jq -r '.[] | if .level == "E" then 
  "\u001b[31m[\(.level)]\u001b[0m \u001b[33m\(.time_utc)\u001b[0m: \(.log)" 
else 
  "[\(.level)] \u001b[33m\(.time_utc)\u001b[0m: \(.log)" 
end'
