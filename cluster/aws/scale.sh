#!/bin/bash
NODES="$1"
if [[ -z "$NODES" ]] ; then
    NODES=2
fi
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
eksctl scale nodegroup --name "$K8SNAME-ng" --cluster "$K8SNAME" --nodes=$NODES
