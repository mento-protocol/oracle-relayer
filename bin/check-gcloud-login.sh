#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

check_gcloud_login() {
	echo "🌀 Checking gcloud login..."
	# Check if there's an active account
	if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
		echo "No active Google Cloud account found. Initiating login..."
		gcloud auth login
		echo "✅ Successfully logged in to gcloud"
	else
		echo "ℹ️  Already logged in to Google Cloud."
	fi
	printf "\n"

	echo "🌀 Checking gcloud application-default credentials..."
	if ! gcloud auth application-default print-access-token &>/dev/null; then
		echo "No valid application-default credentials found. Initiating login..."
		gcloud auth application-default login
		echo "✅ Successfully logged in to gcloud"
	else
		echo "ℹ️  Already logged in with valid application-default credentials."
	fi
	printf "\n"
}

check_gcloud_login
