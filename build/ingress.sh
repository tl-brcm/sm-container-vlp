#!/bin/bash
# STEP 10 - load environment variables
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../base/$VERSHLIB"
fi

# STEP 20 - create name space 
createns "$INGRESS"

# STEP 30 - add and update the helm repo
if [[ -z "$(repoexist "$INGRESSREPO")" ]] ; then
    helm repo add "$INGRESSREPO" "$INGRESSURL"
else
    >&2 echo $INGRESSREPO exists
fi
helm repo update

# STEP 40 - deploy the helm repo (Modify this based on your deployment environment)
if [[ -z "$(relexist "$INGRESS" "$INGRESSREL")" ]] ; then
    helm install "$INGRESSREL" -n "$INGRESS" "$INGRESSREPO"/ingress-nginx \
        --set controller.service.externalTrafficPolicy="Local" \
        --set imagePullSecrets[0].name=docker-hub-reg-pullsecret \
        --set controller.admissionWebhooks.patch.securityContext.runAsUser=101 \
        --set controller.admissionWebhooks.patch.securityContext.fsGroup=$(kubectl get ns ingress -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}'|cut -d '/' -f1) \
        $INGRESSVER \
       --debug > "$INGRESSREL.$INGRESS.$$.debug"
#
# Azure internal load balancer option
#
#        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal"="true" \
#
# AWS internal load balancer option
#
#        --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-internal"="true" \
else
    >&2 echo $INGRESSREL exists
fi
