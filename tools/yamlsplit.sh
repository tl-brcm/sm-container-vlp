#!/bin/bash
BASENAME="$(echo "$(basename "$1")" | sed 's/\.debug$//')"
mkdir -p "$BASENAME"
cd "$BASENAME"
DEBUG="../$1"
csplit "$DEBUG" -f file '/^---$/' '/^NOTES:$/' \
    && sed 's/^---$/#---/' "file01" \
    | csplit -  '/^#---$/' '{*}' \
    && cat xx* | grep -E '^kind|^  name:|^type|^metadata:$' > summary
