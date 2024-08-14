#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Load the project variables
source ./set-project-vars.sh

printf "\n"

# NOTE: The `data` field is base64 encoded. The value of the `data` field is a JSON object that adheres to the pubsub schema.
# For example: `{ "rate_feed_name": "PHP/USD", "relayer_address": "0xefb84935239dacdecf7c5ba76d8de40b077b7b33" }`
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
            "data": "eyJyYXRlX2ZlZWRfbmFtZSI6IlBIUC9VU0QiLCJyZWxheWVyX2FkZHJlc3MiOiIweDMwMDVhMzNhOTc4MkY0YzFjY2ZhMGZGZGI4N0EwMzRiOTVCN2FkOTAifQ==",
            "messageId": "11844765153650126",
            "message_id": "11844765153650126",
            "publishTime": "2024-07-26T11:09:00.513Z",
            "publish_time": "2024-07-26T11:09:00.513Z"
        },
        "subscription": "projects/oracle-relayer-87ee/subscriptions/eventarc-europe-west1-relay-function-540785-sub-226"
      }'
