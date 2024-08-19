#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Load the project variables
source ./set-project-vars.sh

logs_url="https://console.cloud.google.com/functions/details/${region}/${function_name}?project=${project_id}&tab=logs "
printf '\n\033[1m%s\033[0m\n' "${logs_url}"
