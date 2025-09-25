#!/bin/bash
MYPATH="$(cd "${BASH_SOURCE[0]%/*}"; pwd)"
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
. "${MYPATH}/../config.sh"

if [[ -z "$(repoexist "$SMREPO")" ]] ; then
    bash "${MYPATH}/../base/smrepo.sh"
else
    >&2 echo $SMREPO exists
fi

createns "$SMINFRANS"

#
## Deploy Fluent Bit from SiteMinder Infra chart
#
if [[ -z "$(relexist "$SMINFRANS" "$SMINFRAREL")" ]] ; then
    helm install "$SMINFRAREL" $SMREPO/siteminder-infra -n ${SMINFRANS} \
        --set fluent-bit.enabled=true  \
        --set prometheus-adapter.enabled=false $SMVER \
        > /tmp/sminfra-install.log 2>&1

else
    >&2 echo release $SMINFRAREL exists, attempt to upgrade
    helm upgrade --install "$SMINFRAREL" $SMREPO/siteminder-infra -n ${SMINFRANS} \
        --set fluent-bit.enabled=true \
        --set prometheus-adapter.enabled=false $SMVER \
        > /tmp/sminfra-upgrade.log 2>&1
fi
