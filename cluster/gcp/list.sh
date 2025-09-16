#!/bin/bash
MYPATH="$(cd "$(dirname "$0")"; pwd)"
gcloud container clusters list --format json | jq '[ .[] | .name ]'
