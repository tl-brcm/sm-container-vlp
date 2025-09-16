#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}/.."
. ./env.shlib
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../base/$VERSHLIB"
fi
NODE=$1
NODES="$(bash "$MYPATH"/nodesip.sh)"
echo $NODES | jq --arg n "$NODE" -r '.[] | select(.name==$n) | .ip'
