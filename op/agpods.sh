#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}/.."
. ./env.shlib
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../base/$VERSHLIB"
fi
kubectl get pods -n "$AGNS" -o json | \
    jq --arg n "$AGNS" '[ .items[] | 
        { "name": .metadata.name,
	  "ns": $n,
	  "node": .spec.nodeName }
	]'
