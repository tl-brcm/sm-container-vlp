#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}/.."
. ./env.shlib
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../base/$VERSHLIB"
fi
DIR="$1"
NODES="$(bash "$MYPATH"/nodesip.sh)"
LEN=$(echo "$NODES" | jq 'length')
for (( i = 0; i < $LEN; ++i )) ; do
    bash "$CLOUD/sshnodeindex.sh" $i date
done
