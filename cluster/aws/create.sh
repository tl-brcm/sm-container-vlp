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
eksctl create cluster --name=$K8SNAME \
    --node-type="$MTYPE" --nodes-min=$MINNODES --nodes-max=$MAXNODES --managed \
    --ssh-access --nodegroup-name "$K8SNAME-ng" \
    --region=$REGION --version=$K8SVER
#    --node-type="$MTYPE" --nodes=$NODESNUM --managed \
