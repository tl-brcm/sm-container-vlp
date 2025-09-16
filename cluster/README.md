# cluster
cloud platform independent cluster level commands
* use ../env.shlib to decide
	* CLOUD # the cloud platform
	* K8SNAME # Kubernetes Cluster Name
	* K8SVER # Kubernetes Version to use
* create.sh -- to create the cluster
	* use the env.shlib under each platform
	* to find tune the platform specific settings
* delete.sh -- to remove the cluster
* list.sh -- list available clusters
* select.sh -- select and set an available cluster
* az -- Microsoft Azure aks specific implementation
* aws -- Amazon AWS eks specific implementation
* gcp -- Google GCP gke specific implemenation
