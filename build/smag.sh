#!/bin/bash
MYPATH="$(cd "${BASH_SOURCE[0]%/*}"; pwd)"
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
echo "Substituting variables in ${AGVALUES}..."
envsubst < "${MYPATH}/../${AGVALUES}" > /tmp/ag-values.yaml

if [[ -z "$(repoexist \"$SMREPO\")" ]] ; then
    echo "Adding Helm repository..."
    bash "${MYPATH}/../base/smrepo.sh" > /tmp/smrepo.log 2>&1
else
    echo "Helm repository $SMREPO already exists."
fi

echo "Creating namespace ${AGNS} if it doesn't exist..."
createns "$AGNS"

#
## Install SiteMinder Access Gateway chart
#
if ! helm list -n "$AGNS" | grep -q "$AGREL"; then
    echo "Installing SiteMinder Access Gateway..."
    helm install "$AGREL" -n ${AGNS} \
        $SMREPO/access-gateway $SMVER -f /tmp/ag-values.yaml > /tmp/smag-install.log 2>&1
    echo "SiteMinder Access Gateway installation complete. See /tmp/smag-install.log for details."
else
    echo "Upgrading SiteMinder Access Gateway..."
    helm upgrade "$AGREL" -n ${AGNS} \
        $SMREPO/access-gateway $SMVER -f /tmp/ag-values.yaml > /tmp/smag-upgrade.log 2>&1
    echo "SiteMinder Access Gateway upgrade complete. See /tmp/smag-upgrade.log for details."
fi

