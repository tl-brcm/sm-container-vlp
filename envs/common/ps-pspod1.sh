#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
yq -Y --arg m "$(b64enc "$MKEY")" --arg p "$(b64enc "$SPASS")" --arg e "$(b64enc "$EKEY")" \
    '.global.masterKeySeed = $m
    | .global.superuserPassword= $p
    | .global.encryptionKey = $e
    | .policyServer.enabled = true
    '
