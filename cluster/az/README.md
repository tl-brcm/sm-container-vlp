# cluster/az
Azure Specific implementation of the cluster level operations

You need to modify the env.shlib for your own
specific settings. See env.shlib for more details.
Minimally, you need to specify a resource group name and
an optional location name that uses eastus as default value.
A Kubernetes cluster is maintained under a resource group
which in turn is billed under a billing subscription. 
This release attempts to retrieve a default value for your
subscription. You may need to check whether that
works for you.

* az cli cheatsheet
	* AZ CLI Installation
		* the az login pops a Browser, there is no consistent way of ensuring
		* command line login to be supported as of yet
		* It is suggested that you install a build of AZ CLI on a machine
		* where you have a UI to interact with the popped Browser.
		* The point is that the state of the art is about Web support and hence
		* we always have a Brower somewhere.
		* az login -t tenant-you-are-authorized
	* Set Subscription
		* az account set --subscription "SubscriptionName"
		* az account show
	* Create Resource Group in the Supported Region
		* az group create --resource-group groupName --location eastus
	* Install kubectl 
		* az aks install-cli
	* Prep kubectl to work with a particular cluster
		* az aks get-credentials --resource-group azrg --name cluster1
		* this will set up the ./kube/config with information to allow
		* kubectl to work
