#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}/.."
. ./env.shlib
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../base/$VERSHLIB"
fi
INDEX=$1
if [[ -z "$INDEX" ]] ; then
    INDEX=0
fi
OPT="$2"
POD="$(bash agpods.sh | jq ".[$INDEX]")"
NS=$(echo "$POD" | jq -r '.ns')
NAME=$(echo "$POD" | jq -r '.name')
kubectl exec -it "$NAME" -n "$NS" $OPT -- bash
