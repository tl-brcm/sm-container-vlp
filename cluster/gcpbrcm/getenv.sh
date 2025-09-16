#!/bin/bash
gcloud config list --format=json | jq -r '("project: " +.core.project + " zone: " + .compute.zone)'
MYID=$(gcloud info --format json | jq -r '.config.properties.core.account')
echo myid: ${MYID}
