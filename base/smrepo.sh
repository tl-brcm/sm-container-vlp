#!/bin/bash
set -ex
MYPATH="$(cd "${BASH_SOURCE[0]%/*}"; pwd)"
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
. "${MYPATH}/../config.sh"

if repoexist "$SMREPO" ; then
    helm repo remove "$SMREPO"
fi
if [[ -z "$SMID" ]] ; then
    helm repo add "$SMREPO" "$SMURL"
else
    helm repo add "$SMREPO" "$SMURL" \
	    --username "$SMID" \
	    --password "$SMPWD" \
	    --pass-credentials
fi
helm repo update
