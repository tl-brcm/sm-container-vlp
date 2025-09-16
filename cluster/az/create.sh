#!/bin/bash
MYPATH="$(cd "$(dirname "$0")"; pwd)"
. "$MYPATH/../../env.shlib"
showenv
. "${MYPATH}/../../base/env.shlib"
if [[ ! -z "$VERSHLIB" ]] ; then
    . "${MYPATH}/../../base/$VERSHLIB"
fi
cd "$MYPATH"
. ./env.shlib
showenv
az account set --subscription "$SUBNAME"
createrg "$RGNAME" "$RGLOC"
az aks create --name "$K8SNAME" \
    --node-vm-size "$MTYPE" \
    --min-count "$MINNODES" --max-count "$MAXNODES" \
    --node-count "$MINNODES" --enable-cluster-autoscaler \
    --ssh-key-value $SSHPUB --enable-node-public-ip \
    --resource-group "$RGNAME" --kubernetes-version "$K8SVER"
az aks get-credentials --resource-group "$RGNAME" --name "$K8SNAME" --overwrite-existing
MCRGNAME="MC_${RGNAME}_${K8SNAME}_${RGLOC}"
NSGNAME="$(az network nsg list \
    | jq -r --arg s "$MCRGNAME"  '.[] | select(.resourceGroup == $s) | .name')"
az network nsg rule create --resource-group "$MCRGNAME" --nsg-name "$NSGNAME" \
    --name Port_22 --destination-port-ranges 22 --protocol TCP --priority 100
# az aks nodepool add --name cheyi02s1 --resource-group cheyi02-aks --cluster-name cheyi02-ps1 --kubernetes-version 1.21.9 --node-vm-size Standard_B2s  --node-count 1 --mode system --node-taints "CriticalAddonsOnly=true:NoSchedule"
# az aks nodepool delete --name nodepool1 --resource-group cheyi02-aks --cluster-name cheyi02-ps1
# az aks nodepool add --name cheyi02sm1 --resource-group cheyi02-aks --cluster-name cheyi02-ps1 --kubernetes-version 1.21.9  --mode user --node-vm-size Standard_D4s_v3 --enable-cluster-autoscaler --min-count 1 --max-count 4
