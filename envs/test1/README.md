# envs/cadir1
A quick sample environment that uses CA Directory as policy store.

Modify the env.shlib to set your own environment, minimally
you need to set following variables according to your own CA Directory
	* LDAP=CADIRHost:DSAPort
	* RDN="ou=policystore,o=SiteMinder"
	* BDN="uid=smadmin,ou=Admins,ou=policystore,o=SiteMinder"
	* BPASS="P@ssw0rd!"
If your Policy Store is not brand new, you would need to be careful with
	* MKEY: Master Key Seed
	* SPASS: superuser siteminder password
	* EKEY: Encryption Key
If your policy store is brand new, then the setting in the env.shlib will be used.

* run "bash make.sh" to set the environment variables in the right place.
* go to cluster subdirectory and run "bash create.sh" to create a cluster
* after the cluster is up and ready.
* go to build subdirectory, run the following in the given order
	* between steps, use "bash pods.sh" to check their readiness"
	* bash ingress.sh
	* bash enclave.sh
	* bash sminfra.sh
	* bash smps.sh
	* configure the siteminder using the Admin UI
		* UI IP and names can be discovered through
		* the "bash hosts.sh" under build subdirectory
		* when the three objects are in place
		* more info is documented below.
	* bash smag.sh

* server components
	* Common Server Component Docker Registry
	* policy server pod
	* administrative server pod
	* CA Directory Policy Store/Embedded Key Store
	* No Session Store
	* Misc policy server configuration
	* GIT config retriever
	* GIT Runtimee config retriever
* before access gateway can be deployed, you need to manually cretate
	* three siteminder objects: agent, aco, hco to be created first 
	* By default, they are ACO->SecureProxyServer and HCO->InitialHCO
	* The agent object is usually in the ACO as defaultagentname
	* agent object value is made up by administrator used to write authorization policies
	* The ACO SecureProxyServer is a copy of the SPSDefaultSettings and
	* then customized to set the DefaultAgentName  to the agent object created this last step.
	* The InitialHCO needs to set to
	*
	* siteminderserver-siteminder-policy-server.siteminder.svc.cluster.local
	*
	* siteminder release name and namespace name were set to meet the above value.
	*
* access gateway component
	* Common Access Gateway Registry
	* Common Policy Server Settings
	* Simple Policy Server Registration, HCO, ACO, Trusted Host
	* Simple Web Configuration  Nginx Ingress Pass Through No, ...
	* Simple SPS Server Conf Virtual HostName
	* Simple Fed Configuration
	* GIT Config retriever
	* GIT Runtime Config retriever
