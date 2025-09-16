#/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
GITURI="https://$GITREPOBASE;$GITBRANCH"
    yq -Y --arg s "$AGNAME" --arg u "$GITURI" \
            --arg i "$GITID" --arg k $(b64enc "$GITPAT") \
        ' .sso.configuration.type = "git"
        | .sso.configuration.source = $u
        | .sso.configuration.git.creds = "gitcreds"
        | .sso.configuration.git.username = $i
        | .sso.configuration.git.accessToken = $k
        | .sso.configuration.git.folderPath = "/deploy/accessgateway"
        '
