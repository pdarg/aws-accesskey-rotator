#!/bin/bash

USERS=("app-bot" "app-bot1")

# Accept list of users from the command line
if [ -n "$1" ]; then
    USERS=($@)
fi

for BOT in ${USERS[*]}; do
    echo "Deleting access keys for ${BOT}"
    KEYS=$(aws iam list-access-keys --user-name ${BOT} | jq -r '.AccessKeyMetadata[].AccessKeyId')
    for KEY in ${KEYS}; do
        echo "  ${KEY}"
        aws iam delete-access-key \
            --user-name ${BOT}    \
            --access-key-id ${KEY} 2>&1 > /dev/null
    done
done
