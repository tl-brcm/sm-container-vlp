#!/bin/bash
MYPATH="$(cd "$(dirname "$0")"; pwd)"
. "$MYPATH/../../env.shlib"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
cd "$MYPATH"
. ./env.shlib
az aks list | jq '[.[] | .name]'
