#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

select_environment() {
	# Check if environment parameter is provided
	if [[ $# -ne 1 ]]; then
		echo "Usage: $0 <env>"
		echo "Example: $0 staging"
		exit 1
	fi
	env=$1

	# Load the current project variables
	script_dir=$(dirname "$0")
	source "${script_dir}/get-project-vars.sh"

	# Select the desired workspace
	terraform -chdir=infra workspace select "${env}"
	cached_workspace=${workspace}

	# Determine if cache should be invalidated to not deploy to the wrong environment
	if [[ ${env} != "${cached_workspace}" ]]; then
		source "${script_dir}/get-project-vars.sh" --invalidate-cache
	fi
}

select_environment "$@"
