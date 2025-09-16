#!/bin/bash
ID="$1"
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. ./env.shlib
AuthToken=$(curl -s -H "Content-Type: application/json" -X POST \
    -d '{"username": "'$ID'", "password": "'$PASS'"}' \
    https://hub.docker.com/v2/users/login/ | jq -r .token)
curl -s -H "Authorization: JWT $AuthToken" \
    https://hub.docker.com/v2/repositories/$ID/
