#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Load the project variables
source ./set-project-vars.sh

echo "🌀 Emitting a Pubsub event to trigger the function..."
printf "\n"
# TODO: Update the relayer address to a real one once we have one deployed in production
gcloud pubsub topics publish "${topic_name}" --message='{"rate_feed_name": "TEST/USD", "relayer_address": "0x13374935239dacdecf7c5ba76d8de40b077b7420"}'
printf "\n"

echo "✅ Pubsub event emitted!"
printf "\n"

logs_url=$(npm run logs:url 2>/dev/null | tail -n1 || echo "npm run logs:url")
echo "Now check the logs via \`npm run logs\` or in the Cloud Console via ${logs_url}"
