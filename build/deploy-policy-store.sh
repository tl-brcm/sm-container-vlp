#!/bin/bash

# Create the namespace for the policy store
kubectl create ns pstore

# Deploy the policy store using Helm
helm install pstore ssp_helm_charts/ssp-symantec-dir -f review/cadir-values.yaml
