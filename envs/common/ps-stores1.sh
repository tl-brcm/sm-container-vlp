#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
yq -Y --arg s "$SLDAP" --arg r "$SRDN" --arg b "$SBDN" --arg p "$(b64enc "$SBPASS")" \
    '.global.stores.auditStore.enabled = true
    | .global.stores.auditStore.type = "text"
    | .global.stores.sessionStore.enabled = true
    | .global.stores.sessionStore.service = $s
    | .global.stores.sessionStore.userPassword = $p
    | .global.stores.sessionStore.type = "ldap"
    | .global.stores.sessionStore.ldap.type = "cadir"
    | .global.stores.sessionStore.ldap.rootDN = $r
    | .global.stores.sessionStore.ldap.userDN = $b
    '
