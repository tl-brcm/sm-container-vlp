#!/bin/bash
MYPATH="$(cd "${BASH_SOURCE[0]%/*}"; pwd)"
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
. "${MYPATH}/../config.sh"

if [[ -z "$(repoexist "$SMREPO")" ]] ; then
    if [[ -z "$SMID" ]] ; then
        helm repo add "$SMREPO" "$SMURL"
    else
        helm repo add "$SMREPO" "$SMURL" \
	    --username "$SMID" \
	    --password "$SMPWD" \
	    --pass-credentials  
    fi
else
    >&2 echo repo $SMREPO exists
fi
helm repo update
helm search repo "$SMREPO" --versions
