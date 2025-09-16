#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
. "${MYPATH}/../config.sh"

# Read and encode the certificate and key
export TLS_CERT=$(cat "${MYPATH}/../${CERTFILE}" | base64 -w0)
export TLS_KEY=$(cat "${MYPATH}/../${KEYFILE}" | base64 -w0)

# Substitute the variables in the values file
envsubst < "${MYPATH}/../${AGVALUES}" > /tmp/ag-values.yaml

if [[ -z "$(repoexist \"$SMREPO\")" ]] ; then
    bash "${MYPATH}/../base/smrepo.sh"
else
    >&2 echo $SMREPO exists
fi

createns "$AGNS"

#
## Install SiteMinder Access Gateway chart
#
if [[ -z "$(relexist \"$AGNS\" \"$AGREL\")" ]] ; then
    helm install \"$AGREL\" -n ${AGNS} 
        $SMREPO/access-gateway $SMVER -f /tmp/ag-values.yaml 
        --debug > \"$AGREL.$AGNS.$.debug\"
else
    >&2 echo release $AGREL exists, attempt to upgrade
    helm upgrade --install \"$AGREL\" -n ${AGNS} 
        $SMREPO/access-gateway $SMVER -f /tmp/ag-values.yaml 
        --debug > \"$AGREL.$AGNS.$.debug\"
fi
