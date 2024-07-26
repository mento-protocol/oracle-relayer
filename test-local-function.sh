#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Load the project variables
source ./set-project-vars.sh

curl localhost:8080/projects/"${project_name}"/topics/"${topic_name}" \
	-X POST \
	-H "Content-Type: application/json" \
	-d '{
        "message": {
            "attributes": {
              "googclient_schemaencoding": "JSON",
              "googclient_schemarevisionid": "a75ff1fd"
            },
            "data": "eyJyZWxheWVyX2FkZHJlc3MiOiIweGVmYjg0OTM1MjM5ZGFjZGVjZjdjNWJhNzZkOGRlNDBiMDc3YjdiMzMifQ==",
            "messageId": "11844765153650126",
            "message_id": "11844765153650126",
            "publishTime": "2024-07-26T11:09:00.513Z",
            "publish_time": "2024-07-26T11:09:00.513Z"
        },
        "subscription": "projects/oracle-relayer-87ee/subscriptions/eventarc-europe-west1-relay-function-540785-sub-226"
      }'
