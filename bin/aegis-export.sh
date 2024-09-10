#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# If .env exists, source it
if [[ -f .env ]]; then
	# We know at this point that .env exists, so we can safely source it
	# trunk-ignore(shellcheck/SC1091)
	source .env
	# Check if RELAYER_MNEMONIC_SECRET_ID is set, if not, regenerate .env
	if [[ -z ${RELAYER_MNEMONIC_SECRET_ID} ]]; then
		echo 'Env var RELAYER_MNEMONIC_SECRET_ID not found. Regenerating .env...'
		npm run generate:env

		# We know at this point that .env exists because the npm task created it (or failed with an error), so we can safely source it
		# trunk-ignore(shellcheck/SC1091)
		source .env
	fi

# If not, regenerate .env to ensure RELAYER_MNEMONIC_SECRET_ID is set
else
	echo 'Env var RELAYER_MNEMONIC_SECRET_ID not found. Regenerating .env...'
	npm run generate:env
fi

# Print out all signer wallets for all relayers in an aegis-compatible format (so monitoring additional signer wallets becomes as easy as copy-pasting)
echo "Generating aegis-compatible signer wallet export..."
NODE_ENV=development npx ts-node ./src/aegis-export.ts
