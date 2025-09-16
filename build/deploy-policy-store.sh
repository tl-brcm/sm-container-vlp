#!/bin/bash

MYPATH="$(cd "${BASH_SOURCE[0]%/*}"; pwd)"
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
. "${MYPATH}/../config.sh"

# Substitute the variables in the values file
envsubst < "${MYPATH}/../${CADIRVALUES}" > /tmp/cadir-values.yaml

# Create the namespace for the policy store
kubectl create ns pstore

kubectl create configmap sm-root-ldif --from-file "${MYPATH}/../data/sm-root.ldif" -n pstore
kubectl create configmap sm-schemas --from-file "${MYPATH}/../data/" -n pstore

helm repo add "${SSP_HELM_REPO}" "${SSP_HELM_REPO_URL}"
helm repo update

# Deploy the policy store using Helm
helm install pstore ${SSP_HELM_REPO}/ssp-symantec-dir -f /tmp/cadir-values.yaml -n pstore
