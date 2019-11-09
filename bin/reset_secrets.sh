#!/bin/bash

SECRETS=("dev/app-bot-key" "dev/app-bot1-key")

# Accept list of secrets from the command line
if [ -n "$1" ]; then
    SECRETS=($@)
fi

echo "Canceling existing rotations"
for SECRET in ${SECRETS[*]}; do
    echo "  ${SECRET}"
    aws secretsmanager cancel-rotate-secret --secret-id ${SECRET} 2>&1 > /dev/null
done

echo "Resetting secret values"
for SECRET in ${SECRETS[*]}; do
    echo "  ${SECRET}"
    DEFAULT=$(aws secretsmanager get-secret-value --secret-id ${SECRET} | jq -r '.SecretString' | jq '{UserName}')
    aws secretsmanager put-secret-value \
        --secret-id ${SECRET}           \
        --secret-string "${DEFAULT}" 2>&1 > /dev/null
done

echo "Delete old verions"
for SECRET in ${SECRETS[*]}; do
    for STAGE in "AWSPREVIOUS" "AWSPENDING"; do
        VERSION_ID=$(aws secretsmanager list-secret-version-ids --secret-id ${SECRET} | jq -r ".Versions[] | select(.VersionStages[] == \"${STAGE}\") | .VersionId")

        if [ -z "${VERSION_ID}" ]; then
            continue
        fi

        echo "  ${SECRET} -> ${STAGE} :: ${VERSION_ID}"
        aws secretsmanager update-secret-version-stage \
            --secret-id ${SECRET}                      \
            --version-stage ${STAGE}                   \
            --remove-from-version-id ${VERSION_ID} 2>&1 > /dev/null
    done
done
