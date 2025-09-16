#!/bin/bash
COUNT="$1"
if [[ -z "$COUNT" ]]; then
    COUNT=1
fi
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}/.."
. ./env.shlib
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../base/$VERSHLIB"
fi

DEPLOY="$(kubectl get deployments -n "$PSNS" -o json | jq '{ name: .items[0].metadata.name, replicas: .items[0].status.replicas }')"
DEPLOYNAME="$(echo "$DEPLOY" | jq -r ".name")"
R="$(( $(echo "$DEPLOY" | jq -r '.replicas') + $COUNT ))"
kubectl scale deployment "$DEPLOYNAME" -n "$PSNS" --replicas=$R
