#!/bin/bash

SECRETS=("dev/app-bot-key" "dev/app-bot1-key")

# Accept list of secrets from the command line
if [ -n "$1" ]; then
    SECRETS=($@)
fi

for SECRET in ${SECRETS[*]}; do
    echo "Deleting ${SECRET}"
    aws secretsmanager delete-secret    \
        --force-delete-without-recovery \
        --secret-id ${SECRET} 2>&1 > /dev/null
done
