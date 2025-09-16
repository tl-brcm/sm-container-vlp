#!/bin/bash
MYPATH="$(cd "$(dirname "$0")"; pwd)"
. "$MYPATH/../../env.shlib"
showenv
cd "$MYPATH"
. ./env.shlib
showenv
gcloud container clusters delete ${K8SNAME}
