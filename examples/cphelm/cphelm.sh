#!/bin/bash
MYPATH="$(cd "$(dirname "$0")"; pwd)"
cd "$MYPATH"
. ./env.shlib
doDir() {
    local URL="$1"
    local TO="$2"
    local indexJSON
    local LEN
    local i
    indexJSON="$(curl -s -k "$URL" -u "$SMID:$SMPWD" | xq '.html.body.pre[1].a')"
    TYPE=$(echo "$indexJSON" | jq -r 'type')
    if [[ ! "$TYPE" == "array" ]] ; then
        >&2 echo done
        return
    fi
    LEN=$(echo "$indexJSON" | jq 'length')
    for (( i = 0; i < $LEN ; ++i )) ; do
        LINK="$(echo "$indexJSON" | jq -r ".[$i]."'"@href"')"
        if [[ "$LINK" == "../" ]] ; then
            >&2 echo dir $LINK skipped
        elif [[ "$LINK" == */ ]] ; then
            mkdir -p "$TO/$LINK"
            >&2 echo dir $LINK
            doDir "$URL$LINK/" "$TO/$LINK"
        else
            curl -s -k "$URL$LINK" -u "$SMID:$SMPWD" > "$TO/$LINK"
            >&2 echo file $LINK
        fi
    done
    }
doDir "$SMURL/" "$TODIR"
