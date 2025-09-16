kubectl get nodes
kubectl create -f busybox.yml # to create a busybox pod running busybox image
kubectl get pod
kubectl exec -it busybox -- sh
# to start a shell, telnet is available there
# telnet IP port to test connectivity
kubectl create -f https://k8s.io/examples/application/shell-demo.yaml
---
* attrs.sh yamlfile # list all tags of the yamlfile
* yamlsplit.sh debugOutputFromHelmInstall # create a subdirectory
	* and split the output file into usable yaml files
* dockerhubls user -- PASS is configured in env.shlib
* setkeyvalue.sh File Key Value -- set Key/Value pair in file
