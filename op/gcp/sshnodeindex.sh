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
. "${MYPATH}/../../cluster/gcp/env.shlib"

NAME="$(bash "$MYPATH/../nodesip.sh" | jq -r ".[$INDEX].name")"
gcloud compute ssh --zone $ZONE --project $PROJECT $NAME -- $2
