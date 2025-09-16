#/bin/bash
MYPATH=$(cd $(dirname "$0"); pwd)
cd "${MYPATH}"
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
# If Policy Server is within the cluster, service field should be "<policy-server-service-name>.<policy-server-namespace>.svc.cluster.local".
# If Policy Server is in a different cluster exposed using a NodePort, service field should be "<hostname-of- master-node-of-policy-server-cluster>:<NodePort-mapped-to-policy-server-service-account-port>".
# If Policy Server is in a different cluster behind a load balancer, service field should be "<hostname-of- master-node-of-policy-server-cluster>:<load-balancer-port-mapped-to-policy-server-service-account-port>".
# In EKS/AKS, service field should be "<exposed-IP-of-load-balancer-in-front-of-policy-server>:<exposed-load-balancer-port>".
#        --arg u "$PSREGID" --arg p "$PSREGPWD" \
    yq -Y --arg s "$PSREL-siteminder-policy-server.$PSNS.svc.cluster.local" \
        --arg th "$AGTH" --arg a "$AGACO" --arg h "$AGHCO" \
	--arg u "$(b64enc $SMREGID)" --arg p "$(b64enc $SMREGPWD)" \
        --arg m "$(b64enc "$MKEY")" \
        ' .sso.policyServer.service = $s 
        | .sso.accessGateway.trustedHost = $th
        | .sso.accessGateway.aco = $a
        | .sso.accessGateway.hco = $h
        | .masterkey.masterKeySeed = $m
        | .sso.adminPassword = $p
        | .sso.adminUsername = $u
        '
