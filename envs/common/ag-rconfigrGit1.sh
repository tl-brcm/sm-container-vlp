#/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
GITURI="https://$GITREPOBASE;$GITBRANCH"
    yq -Y --arg u "$GITURI" \
            --arg i "$GITID" --arg k $(b64enc "$GITPAT") \
        '
        .sso.runtime.configuration.enabled = true
        | .sso.runtime.configuration.interval = 60
        | .sso.runtime.configuration.type = "git"
        | .sso.runtime.configuration.source = $u
        | .sso.runtime.configuration.git.creds = "runtimegitcreds"
        | .sso.runtime.configuration.git.username = $i
        | .sso.runtime.configuration.git.accessToken = $k
        | .sso.runtime.configuration.git.folderPath = "/runtime/accessgateway"
        '
#.sso.runtime.configuration.aws.accessKey
#.sso.runtime.configuration.aws.creds
#.sso.runtime.configuration.aws.keyID
#.sso.runtime.configuration.aws.region
#.sso.runtime.configuration.enabled
#.sso.runtime.configuration.git.accessToken
#.sso.runtime.configuration.git.creds
#.sso.runtime.configuration.git.folderPath
#.sso.runtime.configuration.git.username
#.sso.runtime.configuration.interval
#.sso.runtime.configuration.resource.cpuRequest
#.sso.runtime.configuration.resource.memoryRequest
#.sso.runtime.configuration.source
#.sso.runtime.configuration.type
