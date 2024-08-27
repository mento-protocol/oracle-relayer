#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Prints the log explorer URL for the Cloud Function and displays it in the terminal.
# Requires an environment arg (e.g., staging, production).
get_function_logs_url() {
	script_dir=$(dirname "$0")
	source "${script_dir}/select-environment.sh" "$1"

	logs_url="https://console.cloud.google.com/functions/details/${region}/${function_name}?project=${project_id}&tab=logs "
	printf '\n\033[1m%s\033[0m\n' "${logs_url}"
}

get_function_logs_url "$@"
