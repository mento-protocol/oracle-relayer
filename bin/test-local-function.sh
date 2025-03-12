#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

print_usage() {
	echo "Usage: $0 <rate_feed_name> <relayer_address>"
	echo "Example: $0 'PHP/USD' '0x9C65c22C96391b0FC09122B86908aD680A8F0FE0'"
	exit 1
}

# Check if both parameters are provided
if [ $# -ne 2 ]; then
	print_usage
fi

rate_feed_name="$1"
relayer_address="$2"

# Manually triggers a local Cloud Function by faking a Pubsub event.
test_local_function() {
	# Load the project variables
	script_dir=$(dirname "$0")
	source "${script_dir}/get-project-vars.sh"

	printf "\n"

	# Create the JSON payload and encode it in base64
	json_data="{ \"rate_feed_name\": \"${rate_feed_name}\", \"relayer_address\": \"${relayer_address}\" }"
	base64_data=$(echo -n "$json_data" | base64)

	curl localhost:8080/projects/"${project_name}"/topics/"${topic_name}" \
		-X POST \
		-H "Content-Type: application/json" \
		-w "\n" \
		-d '{
        "message": {
            "attributes": {
              "googclient_schemaencoding": "JSON",
              "googclient_schemarevisionid": "a75ff1fd"
            },
            "data": "'"${base64_data}"'",
            "messageId": "11844765153650126",
            "message_id": "11844765153650126",
            "publishTime": "2024-07-26T11:09:00.513Z",
            "publish_time": "2024-07-26T11:09:00.513Z"
        },
        "subscription": "projects/oracle-relayer-87ee/subscriptions/eventarc-europe-west1-relay-function-540785-sub-226"
      }'
}

test_local_function
