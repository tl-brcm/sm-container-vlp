#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
createns "$INGRESS"
if [[ -z "$(repoexist "$INGRESSREPO")" ]] ; then
    helm repo add "$INGRESSREPO" "$INGRESSURL"
else
    >&2 echo $INGRESSREPO exists
fi
helm repo update
if [[ -z "$(chartexist "$INGRESS" "$INGRESSREL")" ]] ; then
    >&2 echo $INGRESSREL does not exist
else
    helm uninstall "$INGRESSREL" -n "$INGRESS"
fi
