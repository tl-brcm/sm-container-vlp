#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"

createns "$SMINFRANS"
createns "$PROADPNS"

#
## Deploy Prometheus adapter from SiteMinder Infra chart
#
if [[ -z "$(relexist "$PROADPNS" "$PROADPREL")" ]] ; then
    >&2 echo release $PROADPREL does not exist
else
   helm uninstall "$PROADPREL" -n ${PROADPNS}
fi

#
## Deploy Fluent Bit from SiteMinder Infra chart
#
if [[ -z "$(relexist "$SMINFRANS" "$SMINFRAREL")" ]] ; then
    >&2 echo release $SMINFRAREL does not exist
else
    helm uninstall "$SMINFRAREL" -n ${SMINFRANS}
fi
