# envs/common
Commonly used tools to help maintain a SiteMinder Container Environment.

* Developer Notes
	* For scripts that utilize CERTFILE and KEYFILE environment variables,
	* e.g. ps-admin1.sh and ag-web1.sh, you need to be careful with
	* relative file path issue.
	* For the current release, if they are expressed in absolute path,
	* they will be prefaced with ../ to address the issue where
	* subdirectories under envs is one lower level than other tools
	*

The ps- scripts are commonly used scripts to build a ps-values.yaml file.

* ps-registry.sh -- policy server (server component) docker registry
	* allows private docker registery
* ps-pspod1.sh -- Policy Server Pod Settings
	* Policy Server Pod enabled
	* set three secrets
* ps-admin1.sh -- Administrative Server Pod Settings
	* Administrative Server Pod enabled
	* set Nginx Ingress name and cert
* ps-pstore1.sh -- policy store 1
	* Policy Store using cadir
	* Key Store embedded
* ps-pstore2.sh -- policy store 2
	* Policy Store using mssql
	* Key Store embedded
* ps-stores0.sh -- Audit Text, no Session Store
	* audit store text
* ps-stores1.sh -- Other Stores 1
	* audit store text
	* session store cadir
* ps-stores2.sh -- Other Stores 2
	* audit store text
	* session store mssql
* ps-keystore2.sh -- non-embedded keystore using mssql
* ps-ps1.sh -- policy server configuration
	* trace enabled, in-memory trace disabled
* ps-psNP.sh -- policy server configuration
	* trace enabled, in-memory trace disabled
	* siteminder service type set to NodePort specifically
* ps-psLB.sh -- policy server configuration
	* trace enabled, in-memory trace disabled
	* siteminder service type set to Load Balancer specifically
* ps-configrGit1.sh -- policy server config retriever
	* using GIT Server
	* /deploy/admin for Administrative Server Pod
	* /deploy/policyserver for Policy Server Pod
* ps-rconfigrGit1.sh -- policy server runtime config retriever
	* using GIT Server
	* /runtime/admin for Administrative Server Pod
	* /runtime/policyserver for Policy Server Pod

The ag- scripts are commonly used scripts to build an ag-values.yaml file.
`
* ag-registry.sh -- access gateway (access gateway) docker registry
	* allows private docker registery
* ag-ps1.sh -- Registration with Policy Server
	* set masterkey
	* policyserver service set to use NodePort on the same cluster
	* ACO, HCO, TrustedHost name
	* SiteMinder registration user/password
* ag-web1.sh -- Web Server Settings
	* httpd using default ssl settings, cert supplied by Config Retriever
	* Certificate at Nginix Ingress,  ingress pass through No
* ag-ag1.sh -- Application Server Settings
	* simple Access Gateway virtual host name
* ag-fed1.sh -- Federation Configuration
	* Access Gateway Fed enabled
	* Fed trace enabled
* ag-configrGit1.sh -- access gateway config retriever
	* using GIT Server
	* /deploy/accessgateway for Access Gateway Pod
* ag-rconfigrGit1.sh -- access gateway runtime config retriever
	* using GIT Server
	* /runtime/accessgateway for Access Gateway Pod
