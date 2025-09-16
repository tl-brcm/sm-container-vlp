#!/bin/bash
# This script does generate your ps-value and ag-value file for helm chart deployment. 
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. ./env.shlib

# - Reset the change back to git commits if necessary. 
# resetroot
 resetbase

# This is to choose what to take from base env and what to take from current root env. 
LINES="$(grep '^[^# ]*=' env.shlib | sed 's/=.*$//')"
for i in $LINES ; do
    if [[ "$i" == "CLOUD" ]] ; then
        envroot "$i" "$(eval 'echo $'$i)"
    elif [[ "$i" == "K8SNAME" ]] ; then
        envroot "$i" "$(eval 'echo $'$i)"
    elif [[ "$i" == "K8SVER" ]] ; then
        envroot "$i" "$(eval 'echo $'$i)"
    else
        envbase "$i" "$(eval 'echo $'$i)"
    fi
done
envbase PSVALUES "$MYPATH/ps-values.yaml"
envbase AGVALUES "$MYPATH/ag-values.yaml"
bash "$MYPATH/ps-values.sh" > "$MYPATH/ps-values.yaml"
bash "$MYPATH/ag-values.sh" > "$MYPATH/ag-values.yaml"
