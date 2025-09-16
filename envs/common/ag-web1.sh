#/bin/bash
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
    yq -Y --arg s "$AGNAME" --arg p "$(b64enc password)" \
	  --arg c "$CRT" \
	  --arg k "$KEY" \
        ' .sso.accessGateway.publicHostname = $s
        | .sso.accessGateway.apache.adminEmail = "admin@example.com"
        | .sso.accessGateway.apache.trace = true
        | .sso.accessGateway.apache.ssl.enabled = true
        | .sso.accessGateway.apache.ssl.certFile = "server.crt"
        | .sso.accessGateway.apache.ssl.keyFile = "server.key"
        | .sso.accessGateway.apache.ssl.caFile = "ca-bundle.cert"
        | .sso.accessGateway.apache.ssl.verifyType = "Optional"
        | .sso.accessGateway.apache.ssl.verifyDepth = 10
        | .sso.accessGateway.apache.ssl.creds = "apachesslcreds"
        | .sso.accessGateway.apache.ssl.keyPwd = $p
        | .sso.accessGateway.ingress.virtualHostname = $s
	| .sso.accessGateway.ingress.enableSSLPassThrough = "NO"
        | .sso.accessGateway.ingress.tlsSecret = "acccess-gateway-vhostname-tls"
        | .sso.accessGateway.ingress.tlsCrt = $c
        | .sso.accessGateway.ingress.tlsKey = $k
        '
#.sso.accessGateway.ingress.className
#.sso.accessGateway.ingress.enableSSLPassThrough
#.sso.accessGateway.ingress.tlsCrt
#.sso.accessGateway.ingress.tlsKey
#.sso.accessGateway.ingress.tlsSecret
#.sso.accessGateway.ingress.virtualHostname
