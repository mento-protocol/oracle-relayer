#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

cache_file=".project_vars_cache"

cache_vars() {

	if [[ $* != *"--no-cache"* ]]; then
		printf "No cache file found at %s.\n\n" "${cache_file}"
	fi

	printf "Loading and caching project values...\n\n"

	current_local_project_id=$(gcloud config get project)
	current_tf_state_project_id=$(terraform -chdir=infra state show module.project-factory.module.project-factory.google_project.main | grep project_id | awk '{print $3}' | tr -d '"')

	if [[ ${current_local_project_id} != "${current_tf_state_project_id}" ]]; then
		printf '️\n🚨 Your local gcloud is set to the wrong project: \033[1m%s\033[0m 🚨\n' "${current_local_project_id}"
		printf "\nRunning ./set-project-id.sh in an attempt to fix this...\n\n"
		source ./set-project-id.sh
		printf "\n\n"
	else
		printf " - Project ID:"
		project_id=${current_local_project_id}
		printf ' \033[1m%s\033[0m\n' "${project_id}"
	fi

	printf " - Project Name:"
	project_name=$(awk '/variable "project_name"/{f=1} f==1&&/default/{print $3; exit}' ./infra/variables.tf | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${project_name}"

	printf " - Region:"
	region=$(awk '/variable "region"/{f=1} f==1&&/default/{print $3; exit}' ./infra/variables.tf | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${region}"

	printf " - Service Account:"
	service_account_email=$(terraform -chdir=infra state show "module.project-factory.module.project-factory.google_service_account.default_service_account[0]" | grep email | awk '{print $3}' | tr -d '"')
	printf ' \033[1m%s\033[0m\n' "${service_account_email}"

	printf " - Function Name:"
	function_name=$(awk '/variable "function_name"/{f=1} f==1&&/default/{print $3; exit}' ./infra/variables.tf | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${function_name}"

	printf " - Function Entry Point:"
	function_entry_point=$(awk '/variable "function_entry_point"/{f=1} f==1&&/default/{print $3; exit}' ./infra/variables.tf | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${function_entry_point}"

	printf " - Pubsub Topic:"
	topic_name=$(awk '/variable "pubsub_topic"/{f=1} f==1&&/default/{print $3; exit}' ./infra/variables.tf | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${topic_name}"

	printf "\nCaching values in"
	printf ' \033[1m%s\033[0m...' "${cache_file}"

	{
		echo "project_id=${project_id}"
		echo "project_name=${project_name}"
		echo "region=${region}"
		echo "service_account_email=${service_account_email}"
		echo "function_name=${function_name}"
		echo "function_entry_point=${function_entry_point}"
		echo "topic_name=${topic_name}"
	} >>"${cache_file}"
	printf "✅\n\n"
}

if [[ $* == *"--no-cache"* ]]; then
	echo "Invalidating cache..."
	rm -f "${cache_file}"
	cache_vars --no-cache
elif [[ ! -f ${cache_file} ]]; then
	cache_vars
else
	# shellcheck source=.project_vars_cache
	source "${cache_file}"
	printf "Using cached values:\n"
	printf " - Project ID: \033[1m%s\033[0m\n" "${project_id}"
	printf " - Project Name: \033[1m%s\033[0m\n" "${project_name}"
	printf " - Region: \033[1m%s\033[0m\n" "${region}"
	printf " - Service Account: \033[1m%s\033[0m\n" "${service_account_email}"
	printf " - Function Name: \033[1m%s\033[0m\n" "${function_name}"
	printf " - Function Entry Point: \033[1m%s\033[0m\n" "${function_entry_point}"
	printf " - Pubsub Topic: \033[1m%s\033[0m\n" "${topic_name}"
	printf "\n"
fi
