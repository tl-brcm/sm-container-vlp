#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
yq -Y \
    '.global.policyServerParams.smTrace.enabled = true
    | .global.policyServerParams.inMemoryTrace.enabled = false
    '
