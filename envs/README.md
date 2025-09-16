# envs
Environment Configuration Management

We are using an "Environment" concept to help manage the
possible multiple SiteMinder environments one may need
to work with at any given time.

With this concept, tools have been developed and will be
enhanced over time.

* Pre-requisites

This Environment concept requires you to have read/write
access to a git repository. This repository is likely to
start with the Config Retriever skeleton that has been
published. As of this release, it is available at
https://github.gwd.broadcom.net/ESD/sm2022configr.git.

You need to use this base repository and create a working
repository you have read/write access to. This is because
we believe a working environment should always be configured
with both the Config Retriever and Runtime Config Retriever.
The tools provided here will help you create/maintain
a branch for each Environment.

As a start, except the tools that will be used, each
subdirectory here is used to manage a particular environment. 

* common - subdirectory that keeps environment building tools

As of this initial release, the following sample environments
are provided:

* democadir - a quick sample demo environment that uses
	* CA Directory as the policy store.
* cadir1 - a sample environment that uses CA Directory as stores.
* mssql1 - a sample environment that uses MSSQL as stores.
* mixedstore1 - a sample environment that uses CA Directory as
	* stores while using MSSQL as the non-embedded Keystore

To create your own environments, copy the whole subdirectory of
a provided environment and store under this envs subdirectory.
There are two main sets of tasks for you to prepare your own
environments.

* Modify ps-values.sh and ag-values.sh
	* The two shell scripts are used to create the ps-values.yaml
	* and ag-values.yaml to feed the helm installs
	* You can use the files in the "common" subdirectory as
	* examples when attempt to create your own special settings.
* Modify the env.shlib to supply your own environment values so
	* that the generated ps-values.yaml and ag-values.yaml
	* will contain the settings to work within your environment.
	* The environment variables you set in the env.shlib
	* are used to overwrite setting in the ../../env.shlib or
	* the ../../base/env.shlib.

To actually run one of your environments, use the following steps:

* confirm your Kubernetes provider setting
	* It is the CLOUD variable set in the HOME/env.shlib
	* gcp for GCP, aws for AWS, az for Azure
* change you working subdirectory to the environment
	* e.g. cd HOME/envs/cadir1
* set the current runtime environment by running
	* bash make.sh
* create the cluster and wait until it is ready
	* cd HOME/cluster
	* bash create.sh
* deploying the components that build up your environments
	* NOTE: between the following steps. run
		* run "bash pods.sh" to confirm all podss
		* have become available before next step
	* NOTE: Before the smps.sh, make sure all
		* external stores policy server needs
		* are ready
	* NOTE: Before the smag.sh make sure the three
		* objects, agent object, agent config
		* object and host config object,
		* have been defined in the policy store.
	* bash ingress.sh
	* bash enclave.sh
	* bash sminfra.sh
	* bash smps.sh
	* bash smag.sh
* check the hostnames/IP mapping and configure your name resolution
	* settings.
	* run "bash hosts.sh" will display a list of names and IP
	* that are made available through your environment settings
* Use your Web Browser to confirm the success of the run
	* https://.../iam/siteminder/console/ to connect to AdminUI
	* https://.../affwebservices/public/saml2sso for Access Gateway
