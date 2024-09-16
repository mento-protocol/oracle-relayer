#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Prints the log explorer URL for the Cloud Function and displays it in the terminal.
# Requires an environment arg (e.g., staging, production).
get_function_logs_url() {
	script_dir=$(dirname "$0")
	source "${script_dir}/select-environment.sh" "$1"

	function_logs_url="https://console.cloud.google.com/functions/details/${region}/${function_name}?project=${project_id}&tab=logs "
	printf '\n\033[1mCloud Function Logs\033[0m - The runtime logs of your function, usually this is what you want.\n%s\n' "${function_logs_url}"
	echo ""

	cloud_run_logs_url="https://console.cloud.google.com/run/detail/${region}/${function_name}/logs?${project_id}"
	printf '\n\033[1mCloud Run Logs\033[0m - The underlying Cloud Run logs, mainly for problems occurring during startup of the function.\n%s\n' "${cloud_run_logs_url}"
}

get_function_logs_url "$@"
