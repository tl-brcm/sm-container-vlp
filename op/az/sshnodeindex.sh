#!/bin/bash
INDEX=$1
if [[ -z "$INDEX" ]] ; then
    INDEX=0
fi
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}/../.."
. ./env.shlib
cd "${MYPATH}"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
. "${MYPATH}/../../cluster/az/env.shlib"

IP="$(bash "$MYPATH/../nodesip.sh" | jq -r ".[$INDEX].ip")"
ssh -i "$SSHID" "azureuser@$IP" "$2"
