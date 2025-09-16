#!/bin/bash
FILE=$1
KEY=$2
VALUE=$3
if ! grep -qs "^${KEY}=" "$FILE" ; then
    echo "$KEY=" >> "$FILE"
fi
sed -i -e "s#^${KEY}=.*#${KEY}=\"${VALUE}\"#" "${FILE}"
echo "${VALUE}"
