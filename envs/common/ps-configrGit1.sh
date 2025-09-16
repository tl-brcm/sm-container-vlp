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
	 ' .global.configuration.type = "git"
        | .admin.configuration.source = $u
        | .admin.configuration.gitFolderPath = "/deploy/admin"
        | .global.configuration.git.username = $i
        | .global.configuration.git.accessToken = $k
        | .policyServer.configuration.source = $u
        | .policyServer.configuration.gitFolderPath = "/deploy/policyserver"
        '
# .global.configuration.type
# .global.configuration.git.accessToken
# .global.configuration.git.username
# .admin.configuration.source
# .admin.configuration.git.folderPath
# .policyServer.configuration.gitFolderPath
# .policyServer.configuration.source
