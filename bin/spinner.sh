#!/bin/bash
# Shared spinner utility for displaying loading indicators
# Source this file to use start_spinner and cleanup_spinner functions

# Cleanup function to ensure cursor is restored
cleanup_spinner() {
	# Kill spinner if running
	if [[ -n ${spinner_pid-} ]] && kill -0 "${spinner_pid}" 2>/dev/null; then
		kill "${spinner_pid}" 2>/dev/null || true
	fi
	# Clear spinner line and show cursor
	printf "\r\033[K"
	tput cnorm 2>/dev/null || true
}

# Spinner function to display while fetching logs
# Usage: start_spinner "Loading message..."
start_spinner() {
	local message="${1:-Loading...}"
	local delay=0.1

	# trunk-ignore(shellcheck/SC1003)
	local spin_string='|/-\'

	# Hide cursor
	tput civis 2>/dev/null || true

	(
		while true; do
			local temp=${spin_string#?}
			printf "\r\033[1;36m%c\033[0m %s" "${spin_string}" "${message}"
			spin_string=${temp}${spin_string%"${temp}"}
			sleep "${delay}"
		done
	) &

	spinner_pid=$!
	# Ensure cleanup happens on exit
	trap cleanup_spinner EXIT INT TERM
}
