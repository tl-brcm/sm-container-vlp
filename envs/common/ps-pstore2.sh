#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
yq -Y --arg d "$PDSN" --arg s "$PODBC" --arg n "$PDBNAME" \
      --arg b "$PDBUSER" --arg p "$(b64enc "$PDBPASS")" \
    '.global.policyStore.type = "odbc"
    | .global.policyStore.service = $s
    | .global.policyStore.userPassword = $p
    | .global.policyStore.odbc.type = "mssql"
    | .global.policyStore.odbc.databaseName = $n
    | .global.policyStore.odbc.user = $b
    | .global.policyStore.odbc.DSN = $d
    | .global.stores.keyStore.embedded = "YES"
    '
