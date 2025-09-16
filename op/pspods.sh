#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}/.."
. ./env.shlib
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../base/$VERSHLIB"
fi
kubectl get pods -n "$PSNS" -o json | \
	jq --arg n "$PSNS" '[ .items[] | select(.metadata.name | contains("siteminder-policy-server")) |
        { "name": .metadata.name,
	  "ns": $n,
	  "node": .spec.nodeName }
	]'
