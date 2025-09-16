# envs/mixedstore1o
A sample environment that uses CA Directory as stores
and MSSQL as non-embedded Keystore

Modify the env.shlib to set your own environment.

* server components
	* Common Server Component Docker Registry
	* policy server pod
	* administrative server pod
	* CA Directory Policy Store/Embedded Key Store
	* CA Directory Session Store
	* Misc policy server configuration
	* MSSQL Keystore using different encryption key
	* GIT config retriever
	* GIT Runtimee config retriever
* access gateway component
	* Common Access Gateway Registry
	* Common Policy Server Settings
	* Simple Policy Server Registration, HCO, ACO, Trusted Host
	* Simple Web Configuration Nginx Ingress Pass Through No, ...
	* Simple SPS Server Conf Virtual HostName
	* Simple Fed Configuration
	* GIT Config retriever
	* GIT Runtime Config retriever
