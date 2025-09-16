# smk8s
SiteMinder Container deployment toolkit

This toolkit is meant to provide helps to delpoly SiteMinder
Container form factor to the three main cloud providers,
namely AWS, Azure, and GCP.

* Pre-requsites
	* AWS 
		* aws
		* eksctl
	* Azure
		* azcli
	* GCP
		* gcloud
	* Non-platform specific tools:
		* helm version 3.8+
		* kubenetes 1.21 or 1.22
		* jq
		* yq
		* git
		* git server to host git repository
	* SiteMinder Container Form Factor supported external stores
		* Symantec/CA Directory
		* Microsoft SQL Server, Oracle Database, MySQL Enterprise Edition

* Quick Getting Started Guide
	* Step 0. Fulfill the necessary pre-requires listed above.
	* Step 1. Pick a platform to use this set of script
		* Modify the CLOUD value in the HOME/env.shlib
			* gcp for Google Cloud Platform
			* az for Microsoft Azure
			* aws for Amazon AWS
	* Step 2. Set Platform Specific Parameters
		* Modify the env.shlib under the
		* plaform of your choice to set
		* platform specific settings.
		* see the README.md under the platform
		* specific subdirectory of the cluster
		* for details
	* Step 3. Gather Required Credentials for non-SiteMinder Stores
		* Credentials required to access the official
			* SiteMinder Container helm/docker registry
			* For this beta release, the required
			* information has been pre-seeded in the
			* base/env.shlib as SMURL, SMID, and SMPWD
		* Credentials required to access your own GIT repository
			* This GIT repository is assumed to
			* include the branches made available on
			* https://github.gwd.broadcom.net/ESD/sm2022configr.git.
			* The three pieces information
			* GITREPOBASE, GITIDs, GITPAT
			* will be used in the env.shlib of your environments
	* Step 4. Try either the envs/cadir1 or envs/mssql1
		* cadir1 uses Symantec/CA Directory
			* See the README.md under envs/cadir1
		* mssql1 uses Microsoft SQL database
			* See the README.md under envs/mssql1
	* Step 5. Following the instructions provided in the
		* HOME/envs/README.md to complete the deployment
		* Essentially, the tasks involve creating
		* a Kubernetes cluster, monitoring/deploying the components
		* that make up your SiteMinder container environment,
		* and testing your deployment through a Web Browser.

