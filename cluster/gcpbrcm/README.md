# cluster/gcp
GCP Specific implementation of the cluster level operations

You may need to modify the env.shlib for your own
specific settings. See env.shlib for more details.
The PROJECT specifies the billing responsibity of
the Kubernetes cluster.
ZONE is another important setting that would impact the
networking aspect of your Kubernetes cluster.
This release attempts to retrieve
the default values for both of them.
You may need to check whether that works for you.
