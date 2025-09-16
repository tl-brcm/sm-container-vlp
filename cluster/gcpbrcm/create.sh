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
    --enable-autoscaling --min-nodes=${MINNODES} --max-nodes=${MAXNODES} \
    --enable-ip-alias \
    --network projects/lims001-saas-vpc/global/networks/lims001-vpc \
    --subnetwork projects/lims001-saas-vpc/regions/us-west1/subnetworks/ims001-solution-eng01-${GKE00}-usw1 \
    --cluster-secondary-range-name pods \
    --services-secondary-range-name services \
    --master-ipv4-cidr ${GKEMASTERRANGE} \
    --enable-private-nodes \
    --enable-private-endpoint \
    --enable-master-authorized-networks \
    --disk-type "pd-standard" \
    --master-authorized-networks 10.0.0.0/8
#    --service-account=terraform@lims001-solution-eng01.iam.gserviceaccount.com \
#
## To authorize user MYID
#
kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user ${MYID}
kubectl describe clusterrolebinding cluster-admin-binding
kubectl get nodes
