#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
bash "$MYPATH/../tools/setkeyvalue.sh" "${MYPATH}/../env.shlib" K8SNAME "$1"
cd "${MYPATH}/.."
. ./env.shlib
cd "$MYPATH/$CLOUD"
bash select.sh
