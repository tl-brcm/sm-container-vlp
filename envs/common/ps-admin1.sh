#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
if [[ ! "$CERTFILE" = /* ]] ; then
    CERTFILE="../$CERTFILE"
fi
if [[ ! "$KEYFILE" = /* ]] ; then
    KEYFILE="../$KEYFILE"
fi
CRT="$(cat "$CERTFILE" | base64 -w0)"
KEY="$(cat "$KEYFILE" | base64 -w0)"
yq -Y --arg s "$PSNAME" \
    --arg c "$CRT" \
    --arg k "$KEY" \
    '.admin.enabled = true
    | .admin.ingress.hostName = $s
    | .admin.ingress.tlsSecret = "casso.ca.local-tls"
    | .admin.ingress.tlsCrt = $c
    | .admin.ingress.tlsKey = $k
    '
#    | .admin.ingress.hostname = $s
# .admin.enabled: false
# .admin.ingress.hostName: casso.ca.local
# .admin.ingress.servicePort: 8443
# .admin.ingress.tlsSecret: casso.ca.local-tls
# .admin.ingress.tlsCrt:
# .admin.ingress.tlsKey:
