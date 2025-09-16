# build
This subdirectory keeps the scripts to run after a Kubernetes cluster
is created and ready to use.

After a cluster has been created run the shell script in the following order.
Between steps, you may want to use pods.sh to check a brief status
of all the pods before continue to the next step.

* ingress.sh -- create the nginx ingress controller
	* Requied
* enclave.sh -- install the enclave services
	* Required for Full Implementation
* sminfra.sh -- siteminder integration with the enclave services
	* Required for Full Implementation
* smps.sh -- siteminder policy server
	* Required
* smag.sh -- siteminder access gateway
	* Required for Full Implementation
	* Before running smag, you need to make sure the three
	* objects required for a SiteMinder Access Gateway 
	* to run succeesfully exist on the Policy Server
	* the Access Gateway is to register with.

The following is a list of helpful scripts

* hosts.sh -- show all Nginx IP and host names
* pods.sh -- show all pods progress
	* used to monitor the success of each installation
	* before proceeding to the next stage.
* rmingress.sh -- helm uninstall ingress
* rmsmag.sh -- helm uninstall ag component
* rmsminfra.sh -- helm uninstall siteminder integration with 
	* enclave services
* rmsmps.sh -- helm uninstall server components
