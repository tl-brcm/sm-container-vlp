#/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
helm show values "$SMREPO"/access-gateway $SMVER | \
    yq -Y --arg u "$SMDOCKERID" --arg p "$SMDOCKERPWD" \
          --arg r "$SMDOCKERURL" --arg s "$SMDOCKERREPOBASE" \
        ' .images.sso.registry.credentials.password = $p
        | .images.sso.registry.credentials.username = $u
        | .images.sso.registry.url = $r
        | .images.sso.accessGateway.repository = $s
        | .images.sso.configuration.repository = $s
        | .images.sso.logging.repository = $s
        | .images.sso.metricsExporter.repository = $s
        | .images.sso.runtime.configuration.repository = $s
        '
