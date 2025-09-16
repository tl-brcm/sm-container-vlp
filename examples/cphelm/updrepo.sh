#!/bin/bash
MYPATH="$(cd "$(dirname "$0")"; pwd)"
cd "$MYPATH"
. ./env.shlib
cd "$TODIR"
helm repo index "$HELMREPO" --url "https://$GITPAGE/$HELMREPO" 
cd "$HELMREPO"
git add .
git commit -m "$HELMREPO: reindex"
git push
