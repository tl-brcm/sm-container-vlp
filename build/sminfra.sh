#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../base/$VERSHLIB"
fi

if [[ -z "$(repoexist "$SMREPO")" ]] ; then
    bash "${MYPATH}/../base/smrepo.sh"
else
    >&2 echo $SMREPO exists
fi


#
## Deploy Fluent Bit from SiteMinder Infra chart
#
if [[ -z "$(relexist "$SMINFRANS" "$SMINFRAREL")" ]] ; then
    helm install "$SMINFRAREL" $SMREPO/siteminder-infra -n ${SMINFRANS} \
        --set fluent-bit.enabled=true --set ssoReleaseName=${SSORELEASENAME} \
        --set prometheus-adapter.enabled=false $SMVER \
	--debug > "$SMINFRAREL.$SMINFRANS.$$.debug"
#helm ls -n ${PSNS}
#kubectl get all -n ${PSNS}
#kubectl describe pod <SITEMINDER-INFRA-POD-NAME> -n ${PSNS}
else
    >&2 echo release $SMINFRAREL exists, attempt to upgrade
    helm upgrade --install "$SMINFRAREL" $SMREPO/siteminder-infra -n ${SMINFRANS} \
        --set fluent-bit.enabled=true --set ssoReleaseName=${SSORELEASENAME} \
        --set prometheus-adapter.enabled=false $SMVER \
	--debug > "$SMINFRAREL.$SMINFRANS.$$.debug"
fi
