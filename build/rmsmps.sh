#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"

createns "$PSNS"

#
## Install SiteMinder Server Components chart
#
if [[ -z "$(chartexist "$PSNS" "$PSREL")" ]] ; then
    >&2 echo chart $PSREL does not exist
else
    helm uninstall "$PSREL" -n ${PSNS}
fi
