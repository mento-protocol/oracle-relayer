#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Maps a chain name to its environment (testnet/mainnet)
chain_to_env() {
	case "$1" in
	celo-sepolia | monad-testnet) echo "testnet" ;;
	celo | monad) echo "mainnet" ;;
	*)
		echo "Error: Unknown chain '$1'. Valid chains: celo, celo-sepolia, monad, monad-testnet" >&2
		exit 1
		;;
	esac
}

set_project_id() {
	printf "Looking up terraform workspace..."
	env=$(terraform -chdir=infra workspace show)
	printf ' \033[1m%s\033[0m\n' "${env}"

	# Ensure workspace is a known environment
	if [[ ${env} != "testnet" && ${env} != "mainnet" ]]; then
		echo "Error: Terraform Workspace must be 'testnet' or 'mainnet'."
		echo "Please run 'terraform workspace select <workspace>' in ./infra to switch workspaces."
		exit 1
	fi

	printf "Looking up project name in variables.tf..."
	project_name=$(awk '/variable "project_name"/{f=1} f==1&&/default/{print $3; exit}' ./infra/variables.tf | tr -d '",')-${env}
	printf ' \033[1m%s\033[0m\n' "${project_name}"

	printf "Fetching the project ID..."
	project_id=$(gcloud projects list --filter="name:${project_name}" --format="value(projectId)")

	if [[ -z ${project_id} ]]; then
		printf '\n\033[1;31mError: No project found with name "%s"\033[0m\n' "${project_name}"
		echo "This usually means the GCP project hasn't been created yet."
		echo "Please ensure you've run the terraform apply in ./infra first."
		exit 1
	fi

	printf ' \033[1m%s\033[0m\n' "${project_id}"

	# Set your local default project
	printf "Setting your default project to \033[1m%s\033[0m...\n" "${project_id}"
	{
		output=$(gcloud config set project "${project_id}" 2>&1 >/dev/null)
		status=$?
	}
	if [[ ${status} -ne 0 ]]; then
		printf '\n\033[1;31mError setting gcloud project: %s\033[0m\n' "${output}"
		exit "${status}"
	fi

	# Set the quota project to the governance-watchdog project, some gcloud commands require this to be set
	printf "Setting the quota project to \033[1m%s\033[0m...\n" "${project_id}"
	{
		output=$(gcloud auth application-default set-quota-project "${project_id}" 2>&1 >/dev/null)
		status=$?
	}
	if [[ ${status} -ne 0 ]]; then
		printf '\n\033[1;31mError setting quota project: %s\033[0m\n' "${output}"
		exit "${status}"
	fi

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
	printf "✅"
}

cache_file=".project_vars_cache"

# Function to load values from cache
load_cache() {
	if [[ -f ${cache_file} ]]; then
		# shellcheck disable=SC1090
		source "${cache_file}"
		return 0
	else
		return 1
	fi
}

# Function to write values to cache
write_cache() {
	{
		echo "env=${env}"
		echo "project_id=${project_id}"
		echo "project_name=${project_name}"
		echo "region=${region}"
		echo "service_account_email=${service_account_email}"
		echo "function_entry_point=${function_entry_point}"
		echo "scheduler_job_name=${scheduler_job_name}"
	} >>"${cache_file}"
}

# Function to load & cache values
cache_values() {
	printf "Loading and caching project values...\n\n"

	printf " - Environment (Terraform Workspace)"
	env=$(terraform -chdir=infra workspace show)
	printf ' \033[1m%s\033[0m\n' "${env}"

	printf " - Project Name:"
	project_name=$(awk '/variable "project_name"/{f=1} f==1&&/default/{print $3; exit}' ./infra/variables.tf | tr -d '",')-${env}
	printf ' \033[1m%s\033[0m\n' "${project_name}"

	printf " - Region:"
	region=$(awk '/variable "region"/{f=1} f==1&&/default/{print $3; exit}' ./infra/variables.tf | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${region}"

	printf " - Service Account:"
	service_account_email=$(terraform -chdir=infra state show "module.oracle_relayer.module.project-factory.google_service_account.default_service_account[0]" | grep email | awk '{print $3}' | tr -d '"')
	printf ' \033[1m%s\033[0m\n' "${service_account_email}"

	printf " - Function Entry Point:"
	function_entry_point=$(awk '/variable "function_entry_point"/{f=1} f==1&&/default/{print $3; exit}' ./infra/variables.tf | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${function_entry_point}"

	printf " - Scheduler Job:"
	scheduler_job_name=$(awk '/variable "scheduler_job_name"/{f=1} f==1&&/default/{print $3; exit}' ./infra/variables.tf | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${scheduler_job_name}"

	printf "\nCaching values in"
	printf ' \033[1m%s\033[0m...' "${cache_file}"
	write_cache

	printf "✅\n\n"
}

# Function to invalidate cache
invalidate_cache() {
	printf "Clearing local cache file %s..." "${cache_file}"
	rm -f "${cache_file}"
	printf " ✅\n"

	printf "Loading current local gcloud project ID:"
	current_local_project_id=$(gcloud config get project)
	printf ' \033[1m%s\033[0m\n' "${current_local_project_id}"

	printf "Comparing with project ID from terraform state:"
	current_tf_state_project_id=$(terraform -chdir=infra state show module.oracle_relayer.module.project-factory.google_project.main 2>/dev/null | grep project_id | awk '{print $3}' | tr -d '"' || echo "Not found")
	printf ' \033[1m%s\033[0m\n' "${current_tf_state_project_id}"

	if [[ ${current_local_project_id} != "${current_tf_state_project_id}" ]]; then
		printf '️\n🚨 Your local gcloud is set to the wrong project: \033[1m%s\033[0m 🚨\n' "${current_local_project_id}"
		printf "\nTrying to set the correct project ID...\n\n"
		set_project_id
		printf "\n\n"
	else
		project_id="${current_local_project_id}"
	fi

	cache_values
}

# Derives chain-specific variables from the CHAIN env var or argument.
# Call this after sourcing get-project-vars.sh and setting CHAIN.
set_chain_vars() {
	local chain="${1:-${CHAIN-}}"
	if [[ -z ${chain} ]]; then
		echo "Error: No chain specified. Set CHAIN env var or pass chain as argument." >&2
		exit 1
	fi

	export function_name="relay-${chain}"
	export topic_name="relay-${env}-${chain}"
}

# Main script logic
main() {
	# Check for verbose flag in arguments
	for arg in "$@"; do
		if [[ ${arg} == "--verbose" || ${arg} == "-v" ]]; then
			export VERBOSE=1
		fi
	done

	if [[ ${1-} == "--invalidate-cache" ]]; then
		invalidate_cache
		return 0
	fi

	set +e
	load_cache
	cache_loaded=$?
	set -e

	if [[ ${cache_loaded} -eq 0 ]]; then
		if [[ ${VERBOSE:-0} -eq 1 ]]; then
			printf "Using cached values from %s:\n" "${cache_file}"
			printf " - Environment: \033[1m%s\033[0m\n" "${env}"
			printf " - Project ID: \033[1m%s\033[0m\n" "${project_id}"
			printf " - Project Name: \033[1m%s\033[0m\n" "${project_name}"
			printf " - Region: \033[1m%s\033[0m\n" "${region}"
			printf " - Service Account: \033[1m%s\033[0m\n" "${service_account_email}"
			printf " - Function Entry Point: \033[1m%s\033[0m\n" "${function_entry_point}"
			printf " - Scheduler Job: \033[1m%s\033[0m\n" "${scheduler_job_name}"
		else
			# Calculate the length for proper box sizing
			env_text="Environment: ${env} / Project ID: ${project_id}"
			text_length=${#env_text}

			# Create box border (minimum 60 chars wide)
			box_width=$((text_length > 60 ? text_length + 4 : 64))
			border=$(printf '%*s' "${box_width}" '' | tr ' ' '-')

			printf "\n"
			printf "+%s+\n" "${border}"
			printf "| \033[1mEnvironment:\033[0m %s / \033[1mProject ID:\033[0m %s" "${env}" "${project_id}"

			# Calculate padding to align closing pipe
			padding=$((box_width - text_length - 1))
			printf "%*s|\n" "${padding}" ""
			printf "+%s+\n" "${border}"
		fi
	else
		printf "⚠️ No cache found. Setting project Id and fetching values...\n\n"
		set_project_id
		cache_values
	fi

	# If CHAIN is set, derive chain-specific variables
	if [[ -n ${CHAIN-} ]]; then
		set_chain_vars "${CHAIN}"
	fi
}

main "$@"
