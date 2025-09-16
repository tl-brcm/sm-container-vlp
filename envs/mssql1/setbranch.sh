#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
bash "$MYPATH/../../tools/setkeyvalue.sh" \
    ./env.shlib GITBRANCH "$(basename "$MYPATH")"
