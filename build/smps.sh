#!/bin/bash
# STEP 10 - load environment variables
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
. "${MYPATH}/../config.sh"

# Read and encode the certificate and key
export TLS_CERT=$(cat "${MYPATH}/../${CERTFILE}" | base64 -w0)
export TLS_KEY=$(cat "${MYPATH}/../${KEYFILE}" | base64 -w0)

# Substitute the variables in the values file
envsubst < "${MYPATH}/../${PSVALUES}" > /tmp/ps-values.yaml

# STEP 20 - add siteminder repo and create namesapce
if [[ -z "$(repoexist \"$SMREPO\")" ]] ; then
    bash "${MYPATH}/../base/smrepo.sh"
else
    >&2 echo $SMREPO exists
fi

createns "$PSNS"

#
# STEP 30 - Install SiteMinder Server Components chart
#
if [[ -z "$(relexist \"$PSNS\" \"$PSREL\")" ]] ; then
    helm install "$PSREL" -n ${PSNS} \
        $SMREPO/server-components $SMVER -f /tmp/ps-values.yaml \
	--debug > "$PSREL.$PSNS.$.debug"
else
    >&2 echo release $PSREL exists, attempt to upgrade
    helm upgrade --install "$PSREL" -n ${PSNS} \
        $SMREPO/server-components $SMVER -f /tmp/ps-values.yaml \
        --debug > "$PSREL.$PSNS.$.debug"
fi
