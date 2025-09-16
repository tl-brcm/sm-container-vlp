#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
yq -Y --arg d "$SDSN" --arg s "$SODBC" --arg n "$SDBNAME" \
      --arg b "$SDBUSER" --arg p "$(b64enc "$SDBPASS")" \
    '.global.stores.auditStore.enabled = true
    | .global.stores.auditStore.type = "text"
    | .global.stores.sessionStore.enabled = true
    | .global.stores.sessionStore.service = $s
    | .global.stores.sessionStore.userPassword = $p
    | .global.stores.sessionStore.type = "odbc"
    | .global.stores.sessionStore.odbc.type = "mssql"
    | .global.stores.sessionStore.odbc.databaseName = $n
    | .global.stores.sessionStore.odbc.user = $b
    | .global.stores.sessionStore.odbc.DSN = $d
    '
