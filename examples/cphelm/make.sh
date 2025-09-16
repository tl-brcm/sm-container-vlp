#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. ./env.shlib
#resetroot
resetbase
LINES="$(grep '^.*=' env.shlib | sed 's/=.*$//')"
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
rm -fr "${MYPATH}/cr${GITTO}"
cd "${MYPATH}"
bash "$MYPATH/clone.sh"
rm -fr "${MYPATH}/cr${GITTO}/${HELMREPO}"
bash "$MYPATH/cphelm.sh"
bash "$MYPATH/updrepo.sh"
