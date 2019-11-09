#!/bin/bash

SECRETS=("dev/app-bot-key" "dev/app-bot1-key")

# Accept list of secrets from the command line
if [ -n "$1" ]; then
    SECRETS=($@)
fi

echo "Note: use this when testing ONLY!"
for SECRET in ${SECRETS[*]}; do
    echo ""
    echo "Showing ${SECRET}"
    echo "Versions:"
    VERSIONS=$(aws secretsmanager list-secret-version-ids --secret-id ${SECRET})
    jq <<< ${VERSIONS}

    for STAGE in "AWSCURRENT" "AWSPREVIOUS" "AWSPENDING"; do
        echo ${STAGE}
        EXISTS=$(jq ".Versions[] | select(.VersionStages[] | contains(\"${STAGE}\"))" <<< ${VERSIONS})
        if [ -n "${EXISTS}" ]; then
            aws secretsmanager get-secret-value --secret-id ${SECRET} --version-stage ${STAGE} | jq -r '.SecretString' | jq
        else
            echo "Stage not set"
        fi
    done
done
