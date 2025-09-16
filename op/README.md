# op
Operation Phase utilities. There are platform specific facilities.
* nodesip.sh - returns external IPs for all nodes.
* nodeip.sh nodeName -- return external IP of a particular node
* adminpods.sh -- list administrative server pods and their k8s worker nodes
* pspods.sh -- list policy server pods and their k8s worker nodes
* agpods.sh -- list access gateway pods and their k8s worker nodes
* nodesdate.sh -- run date on all nodes using $CLOUD/sshnodeindex.sh as a "demo"
* sshnodeindex.sh optionalIndex -- ssh to worker node, defaul 0
* scaleps.sh optionalNumber -- positive to scale up negative to scale down, def 1
* scaleag.sh optionalNumber -- positive to scale up negative to scale down, def 1
* sshpsindex.sh optionalIndex optionalOptions -- ssh to policy server using index
	* index default 0, optionalOptions to choose non-default container
	* e.g. "-c policy-server-log" to ssh to policy server log container
* sshadminindex.sh optionalIndex optionalOptions -- ssh to administrative server pod using index
	* similar to sshpsindex.sh
* sshagindex.sh optionalIndex optionalOptions -- ssh to access gateway pod using index
	* similar to sshpsindex.sh
* restartadmin.sh -- resart admin pod
* restartag.sh -- restart access gateway pod
* restartps.sh -- restart policy server pod
