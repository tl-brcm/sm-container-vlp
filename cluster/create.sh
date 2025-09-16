#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}/.."
. ./env.shlib
cd "$MYPATH/$CLOUD"
bash create.sh
