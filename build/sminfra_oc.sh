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

createns "$SMINFRANS"
createns "$PROADPNS"

export SMSERVER_UID=1000690000
export SMSERVER_GID=1000690000
export SMSERVER_FSGROUP=1000690000

#
## Deploy Prometheus adapter from SiteMinder Infra chart
#
if [[ -z "$(relexist "$PROADPNS" "$PROADPREL")" ]] ; then
   helm install "$PROADPREL" $SMREPO/siteminder-infra -n ${PROADPNS} \
       --set prometheus-adapter.enabled=true \
       --set fluent-bit.enabled=false $SMVER \
       --debug >  "$PROADPREL.$PROADPNS.$$.debug"
# kubectl get pods -n ${PROMETHEUS_ADAPTER_NAMESPACE}
# kubectl describe pod <PROMETHEUS-ADAPTER-POD-NAME> -n ${PROMETHEUS_ADAPTER_NAMESPACE}
else
    >&2 echo release $PROADPREL exists, attempt to upgrade
    helm upgrade --install "$PROADPREL" $SMREPO/siteminder-infra -n ${PROADPNS} \
       --set prometheus-adapter.enabled=true \
       --set fluent-bit.enabled=false $SMVER \
       --debug >  "$PROADPREL.$PROADPNS.$$.debug"
fi

#
## Deploy Fluent Bit from SiteMinder Infra chart
#
if [[ -z "$(relexist "$SMINFRANS" "$SMINFRAREL")" ]] ; then
    helm install "$SMINFRAREL" $SMREPO/siteminder-infra -n ${SMINFRANS} \
       --set global.securityContext.fsGroup=${SMSERVER_FSGROUP} \
       --set global.securityContext.runAsUser=${SMSERVER_UID} \
       --set global.securityContext.runAsGroup=${SMSERVER_GID} \
       --set fluent-bit.enabled=true \
       --set fluent-bit.openShift.enabled=true \
       --set fluent-bit.openShift.securityContextConstraints.create=true \
       --set ssoReleaseName=${SSORELEASENAME} \
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
