# Symantec Directory Sample ID Store

This is a SAMPLE Symantec Directory deployment to be used for demo purposes only as an identity store for Symantec Secure Services Platform (SSP)
***DO NOT USE IN PRODUCTION. THIS VERSION OF Symantec Directory IS NOT SUPPORTED AND SHOULD BE USED FOR TESTING PURPOSES ONLY.

## TL;DR;
NOTE: please replace "<username>" and "<password>" with the actual account

On BareMetal:
```console
$ helm install idstore -n <namespace> ssp_helm_charts/ssp-symantec-dir --set service.nodePort=31888 --set global.registry.credentials.username="<username>" --set global.registry.credentials.password="<password>"
```

On a Cloud Platform (e.g. GKE):
 ```console
$ helm install idstore -n <namespace> ssp_helm_charts/ssp-symantec-dir --set service.type=LoadBalancer --set service.servicePort=389 --set global.registry.credentials.username="<username>" --set global.registry.credentials.password="<password>"
```


## Introduction

This chart creates a Symantec Directory deployment on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.4+

## Installing the Chart

Use the following command to get the values.yaml, update the file to match your desired configuration and use the -f command to pass your configuration through the values.yaml file.

 ```console
$ helm inspect values ssp_helm_charts/ssp-symantec-dir >symantecdir-values.yaml

#edit symantecdir-values.yaml...

$ helm install symantecdir -n <namespace> ssp_helm_charts/ssp-symantec-dir -f symantecdir-values.yaml

```

> **Tip**: List all releases using `helm list --all-namespaces`

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```console
$ helm uninstall my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.


***DO NOT USE IN PRODUCTION. THIS VERSION OF Symantec Directory IS NOT SUPPORTED AND SHOULD BE USED FOR TESTING PURPOSES ONLY.


