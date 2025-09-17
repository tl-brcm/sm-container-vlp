#!/bin/bash
MYPATH="$(cd "${BASH_SOURCE[0]%/*}"; pwd)"
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"

#
## Install SiteMinder Access Gateway chart
#
if [[ -z "$(relexist "$AGNS" "$AGREL")" ]] ; then
    >&2 echo release $AGREL does not exist
else
    helm uninstall "$AGREL" -n ${AGNS}
fi

kubectl delete ns ${AGNS}
