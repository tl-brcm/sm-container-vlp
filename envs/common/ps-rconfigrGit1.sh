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
        '.global.runtimeConfiguration.intervalSeconds = 60
        | .global.runtimeConfiguration.type = "git"
        | .global.runtimeConfiguration.git.accessToken = $k
        | .global.runtimeConfiguration.git.username = $i
        | .admin.runtimeConfiguration.enabled = true
        | .admin.runtimeConfiguration.source = $u
        | .admin.runtimeConfiguration.runtimeGitFolderPath = "/runtime/admin"
        | .policyServer.runtimeConfiguration.enabled = true
        | .policyServer.runtimeConfiguration.source = $u
        | .policyServer.runtimeConfiguration.runtimeGitFolderPath = "/runtime/policyserver"
        '
#.global.runtimeConfiguration.aws.accessKey
#.global.runtimeConfiguration.aws.keyID
#.global.runtimeConfiguration.aws.region
#.global.runtimeConfiguration.cpuRequest
#.global.runtimeConfiguration.git.accessToken
#.global.runtimeConfiguration.git.username
#.global.runtimeConfiguration.image
#.global.runtimeConfiguration.intervalSeconds
#.global.runtimeConfiguration.memoryRequest
#.global.runtimeConfiguration.repository
#.global.runtimeConfiguration.tag
#.global.runtimeConfiguration.type
#.admin.runtimeConfiguration.enabled
#.admin.runtimeConfiguration.runtimeGitFolderPath
#.admin.runtimeConfiguration.source
#.policyServer.runtimeConfiguration.enabled
#.policyServer.runtimeConfiguration.runtimeGitFolderPath
#.policyServer.runtimeConfiguration.source
