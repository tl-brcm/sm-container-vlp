#!/bin/bash
F=$1
L=.
qattr() {
    local s="$1"
    if [[ "$s" == *"-"* ]] ; then
        echo '"'"$s"'"'
    elif [[ "$s" == *"/"* ]] ; then
        echo '"'"$s"'"'
    else
	echo "$s"
    fi
    }

prattr() {
    local _lead=$1
    local KEYS
    local i
    local len
    local next
    local TYPE
    if [[ -z "$_lead" ]] ; then
        next="."
    else
        next="$_lead"
    fi
    TYPE="$(yq -r "$next | type" "$F")"
    if [[ "$TYPE" == "object" ]] ; then
        KEYS="$(yq "$next | keys" "$F")"
        len=$(echo "$KEYS" | jq 'length')
#>&2 echo $len "$KEYS"
        for (( i = 0 ; i < $len ; ++i )) ; do
		prattr "$_lead."$(qattr "$(echo "$KEYS" | jq -r ".[$i]")")""
        done
        if [ "$len" -eq 0 ] ; then
            echo $_lead
        fi
    elif [[ "$TYPE" == "array" ]] ; then
        KEYS="$(yq "$next | keys" "$F")"
        len=$(echo "$KEYS" | jq 'length')
#>&2 echo "array caught $_lead $KEYS $len"
        for (( i = 0 ; i < $len ; ++i )) ; do
            prattr "$_lead[$(echo "$KEYS" | jq -r ".[$i]")]"
        done
        if [ "$len" -eq 0 ] ; then
            echo $_lead'[]'
        fi
    else
        echo "$_lead"
    fi
    }

prattr ""
