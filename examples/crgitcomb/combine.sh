#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "./env.shlib"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi

PICKLIST=
gitpick() {
    local _branch="$1"
    git log "origin/$_branch" | head -1 | cut -f2 -d' '
    }
buildPickList() {
    local cherries
    cherries="$(echo "$GITCHERRIES" | awk 'BEGIN{ RS="," } {print $0}')"
    for i in $cherries; do
        PICKLIST="$(jaddToList "$PICKLIST" "$(gitpick "$i")")"
    done
    }
GITREPO="https://${GITID}:${GITPAT}@${GITREPOBASE}"
cd "${MYPATH}/cr${GITTO}"
buildPickList
echo "$PICKLIST" | jq '.'
git push --delete origin "$GITTO"
git checkout -b "$GITTO"
LEN=$(echo "$PICKLIST" | jq 'length')
if [[ -z "$LEN" ]] ; then
    LEN=0
fi
for (( i = 0; i < $LEN; ++i )); do
    PICK="$(echo "$PICKLIST" | jq -r ".[$i]")"
    git cherry-pick "$PICK"
done
git push -u origin "$GITTO"
