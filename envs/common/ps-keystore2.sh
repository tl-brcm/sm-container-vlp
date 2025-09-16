#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
yq -Y --arg d "$KDSN" --arg s "$KODBC" --arg n "$KDBNAME" \
      --arg b "$KDBUSER" --arg p "$(b64enc "$KDBPASS")" \
      --arg e "$(b64enc "$KEKEY")" \
    '.global.stores.keyStore.embedded = "NO"
    | .global.stores.keyStore.encryptionKey = $e
    | .global.stores.keyStore.type = "odbc"
    | .global.stores.keyStore.odbc.DSN = $d
    | .global.stores.keyStore.service = $s
    | .global.stores.keyStore.odbc.databaseName= $n
    | .global.stores.keyStore.odbc.type = "mssql"
    | .global.stores.keyStore.odbc.user = $b
    | .global.stores.keyStore.userPassword = $p
    '
#.global.stores.keyStore.embedded
#.global.stores.keyStore.encryptionKey
#.global.stores.keyStore.ldap.rootDN
#.global.stores.keyStore.ldap.ssl.enabled
#.global.stores.keyStore.ldap.type
#.global.stores.keyStore.ldap.userDN
#.global.stores.keyStore.odbc.DSN
#.global.stores.keyStore.odbc.databaseName
#.global.stores.keyStore.odbc.oracle.databaseServiceName
#.global.stores.keyStore.odbc.ssl.enabled
#.global.stores.keyStore.odbc.ssl.hostNameInCertificate
#.global.stores.keyStore.odbc.ssl.trustPassword
#.global.stores.keyStore.odbc.ssl.trustStore
#.global.stores.keyStore.odbc.type
#.global.stores.keyStore.odbc.user
#.global.stores.keyStore.service
#.global.stores.keyStore.type
#.global.stores.keyStore.userPassword
