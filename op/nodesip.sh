#!/bin/bash
# kubectl get nodes -o json | jq '[ .items[] | .status.addresses[]| select(.type=="ExternalIP")|.address]'
kubectl get nodes -o json | \
    jq '[ .items[] | 
        { "name": .metadata.name, "ip": (.status.addresses[]| select(.type=="ExternalIP")|.address) }]'
