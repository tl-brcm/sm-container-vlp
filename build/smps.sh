#!/bin/bash
# STEP 10 - load environment variables
MYPATH="$(cd "${BASH_SOURCE[0]%/*}"; pwd)"
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
. "${MYPATH}/../config.sh"

# Read and encode the certificate and key
export TLS_CERT=$(cat "${MYPATH}/../${CERTFILE}" | base64 -w0)
export TLS_KEY=$(cat "${MYPATH}/../${KEYFILE}" | base64 -w0)

# Substitute the variables in the values file
echo "Substituting variables in ${PSVALUES}..."
envsubst < "${MYPATH}/../${PSVALUES}" > /tmp/ps-values.yaml

# STEP 20 - add siteminder repo and create namesapce
if [[ -z "$(repoexist \"$SMREPO\")" ]] ; then
    echo "Adding Helm repository..."
    bash "${MYPATH}/../base/smrepo.sh" > /tmp/smrepo.log 2>&1
else
    echo "Helm repository $SMREPO already exists."
fi

echo "Creating namespace ${PSNS} if it doesn't exist..."
createns "$PSNS"

#
# STEP 30 - Install SiteMinder Server Components chart
#
if ! helm list -n "$PSNS" | grep -q "$PSREL"; then
    echo "Installing SiteMinder Server Components..."
    helm install "$PSREL" -n ${PSNS} \
        $SMREPO/server-components $SMVER -f /tmp/ps-values.yaml > /tmp/smps-install.log 2>&1
    echo "SiteMinder Server Components installation complete. See /tmp/smps-install.log for details."
else
    echo "Upgrading SiteMinder Server Components..."
    helm upgrade "$PSREL" -n ${PSNS} \
        $SMREPO/server-components $SMVER -f /tmp/ps-values.yaml > /tmp/smps-upgrade.log 2>&1
    echo "SiteMinder Server Components upgrade complete. See /tmp/smps-upgrade.log for details."
fi


