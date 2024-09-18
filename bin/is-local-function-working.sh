#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Script used in the git pre-push hook to check if the local cloud function can start

# Function to kill the background process
cleanup() {
	if [ ! -z "$PID" ]; then
		kill $PID 2>/dev/null
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
if kill -0 $PID 2>/dev/null; then
	printf "\n✅ Local Function started successfully.\n"
	exit 0
else
	printf "\n❌ Local Function failed to start or crashed.\n"
	exit 1
fi
