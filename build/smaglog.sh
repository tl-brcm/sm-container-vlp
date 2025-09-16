#!/bin/bash
OPT=$1
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../base/$VERSHLIB"
fi
POD=$(kubectl get pods -n "$AGNS" -o json | jq -r '.items[0].metadata.name')
if [[ -z "$OPT" ]] ; then
    OPT="-c access-gateway"
fi
kubectl logs "$POD" -n "$AGNS" $OPT
