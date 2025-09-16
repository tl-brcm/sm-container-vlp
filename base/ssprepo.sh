#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
. "${MYPATH}/env.shlib"
if [[ -z "$(repoexist "$SSPREPO")" ]] ; then
    if [[ -z "$SSPID" ]] ; then
        helm repo add "$SSPREPO" "$SSPURL"
    else
        helm repo add "$SSPREPO" "$SSPURL" \
	    --username "$SSPID" \
	    --password "$SSPPWD" \
	    --pass-credentials  
    fi
else
    >&2 echo repo $SSPREPO exists
fi
helm repo update
helm search repo "$SSPREPO" --versions
