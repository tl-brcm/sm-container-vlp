#!/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
bash ../common/ps-registry.sh \
    | bash ../common/ps-pspod1.sh \
    | bash ../common/ps-admin1.sh \
    | bash ../common/ps-pstore1.sh \
    | bash ../common/ps-stores1.sh \
    | bash ../common/ps-keystore2.sh \
    | bash ../common/ps-psNP.sh \
    | bash ../common/ps-configrGit1.sh \
    | bash ../common/ps-rconfigrGit1.sh
