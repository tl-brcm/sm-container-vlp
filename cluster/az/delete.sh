#!/bin/bash
MYPATH="$(cd "$(dirname "$0")"; pwd)"
. "$MYPATH/../../env.shlib"
showenv
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
cd "$MYPATH"
. ./env.shlib
showenv
az account set --subscription "$SUBNAME"
az aks delete  --resource-group "$RGNAME" --name "$K8SNAME"
