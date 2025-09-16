# envs/mssql1
A sample environment that uses MSSQL as stores.

Modify the env.shlib to set your own environment.

* server components
	* Common Server Component Docker Registry
	* policy server pod
	* administrative server pod
	* MSSQL Policy Store/Embedded Key Store
	* MSSQL Session Store
	* Misc policy server configuration
	* GIT config retriever
	* GIT Runtimee config retriever
* access gateway component
	* Common Access Gateway Registry
	* Common Policy Server Settings
	* Simple Policy Server Registration, HCO, ACO, Trusted Host
	* Simple Web Configuration  Nginx Ingress Pass Through No, ...
	* Simple SPS Server Conf Virtual HostName
	* Simple Fed Configuration
	* GIT Config retriever
	* GIT Runtime Config retriever
