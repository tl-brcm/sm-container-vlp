#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
GITREPO="https://${GITID}:${GITPAT}@${GITREPOBASE}"
git clone -b "$GITFROM" "$GITREPO" "cr${GITTO}"
