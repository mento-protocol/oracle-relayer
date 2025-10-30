#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

#######################################################################################
# Script used in the git pre-push hook to check if the local cloud function can start #
#######################################################################################

# Initialize PID variable
PID=""

# Function to kill the background process and all its children
cleanup() {
	# trunk-ignore(shellcheck/SC2317)
	if [[ -n ${PID} ]]; then
		# Kill the process group to ensure all child processes are terminated
		# trunk-ignore(shellcheck/SC2317)
		pkill -P "${PID}" 2>/dev/null || true
		# trunk-ignore(shellcheck/SC2317)
		kill "${PID}" 2>/dev/null || true
		# Give it a moment to terminate gracefully
		# trunk-ignore(shellcheck/SC2317)
		sleep 1
		# Force kill if still running
		# trunk-ignore(shellcheck/SC2317)
		kill -9 "${PID}" 2>/dev/null || true
	fi
}

# Set up trap to ensure cleanup on exit
trap cleanup EXIT

# Start the function in the background and store the PID
npm start &
PID=$!

# Wait for the function to start (adjust the sleep time if needed)
sleep 5

# Check if the process is still running
if kill -0 "${PID}" 2>/dev/null; then
	printf "\n✅ Local Function started successfully.\n"
	exit 0
else
	printf "\n❌ Local Function failed to start or crashed.\n"
	exit 1
fi
