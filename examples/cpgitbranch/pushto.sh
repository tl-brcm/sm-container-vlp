#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "./env.shlib"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi

cd "${MYPATH}/cr${GITTO}"
GITREPO="https://${GITTID}:${GITTPAT}@${GITTBASE}"
git remote add to "$GITREPO"
git fetch to
git push to --delete "${GITTO}"
git push to "${GITTO}"
