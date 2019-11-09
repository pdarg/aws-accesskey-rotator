#!/bin/bash

SECRETS=("dev/app-bot-key" "dev/app-bot1-key")

# Accept list of secrets from the command line
if [ -n "$1" ]; then
    SECRETS=($@)
fi

for SECRET in ${SECRETS[*]}; do
    echo "Rotating ${SECRET}"
    aws secretsmanager rotate-secret --secret-id ${SECRET}
done
