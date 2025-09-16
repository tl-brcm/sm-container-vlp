#!/bin/bash
MYPATH="$(cd "$(dirname "$0")"; pwd)"
. "$MYPATH/../../env.shlib"
showenv
cd "$MYPATH"
. ./env.shlib
showenv
#    --image-type "COS" \
gcloud container clusters create ${K8SNAME} \
    --zone=${ZONE} \
    --cluster-version=${K8SVER} \
    --machine-type=${MTYPE} --release-channel rapid --num-nodes=${NODESNUM} \
    --enable-autoscaling --min-nodes=${MINNODES} --max-nodes=${MAXNODES}
#
## To authorize user MYID
#
kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user ${MYID}
kubectl describe clusterrolebinding cluster-admin-binding
kubectl get nodes
