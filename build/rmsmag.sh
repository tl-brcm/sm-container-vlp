#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"

createns "$AGNS"

#
## Install SiteMinder Access Gateway chart
#
if [[ -z "$(relexist "$AGNS" "$AGREL")" ]] ; then
    >&2 echo release $AGREL does not exist
else
    helm uninstall "$AGREL" -n ${AGNS}
fi
