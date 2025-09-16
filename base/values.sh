#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../base/$VERSHLIB"
fi
VER=$(echo "$SMVER" | cut -d= -f2)
helm show values "$SMREPO"/siteminder-infra $SMVER > infra-values.$VER.yaml
helm show values "$SMREPO"/server-components $SMVER > ps-values.$VER.yaml
helm show values "$SMREPO"/access-gateway $SMVER > ag-values.$VER.yaml
>&2 echo computing ps-tags.$VER.txt ...
bash ../tools/attrs.sh ps-values.$VER.yaml > ps-tags.$VER.txt
>&2 echo computing ag-tags.$VER.txt ...
bash ../tools/attrs.sh ag-values.$VER.yaml > ag-tags.$VER.txt
>&2 echo computing infra-tags.$VER.txt ...
bash ../tools/attrs.sh infra-values.$VER.yaml > infra-tags.$VER.txt
