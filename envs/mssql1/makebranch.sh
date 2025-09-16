
#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. ./env.shlib
MAKER="${MYPATH}/../../examples/crgitcomb"
git checkout "$MAKER/env.shlib"
bash "$MYPATH/../../tools/setkeyvalue.sh" \
    "$MAKER/env.shlib" GITREPOBASE "$GITREPOBASE"
bash "$MYPATH/../../tools/setkeyvalue.sh" \
    "$MAKER/env.shlib" GITID "$GITID"
bash "$MYPATH/../../tools/setkeyvalue.sh" \
    "$MAKER/env.shlib" GITPAT "$GITPAT"
bash "$MYPATH/../../tools/setkeyvalue.sh" \
    "$MAKER/env.shlib" GITFROM "$GITFROM"
bash "$MYPATH/../../tools/setkeyvalue.sh" \
    "$MAKER/env.shlib" GITCHERRIES "$GITCHERRIES"
bash "$MYPATH/../../tools/setkeyvalue.sh" \
    "$MAKER/env.shlib" GITTO "$GITBRANCH"
cd "$MAKER"
bash make.sh
