# cluster/aws
This subdirectory contains AWS specific implementation
of the cluster level operations.

You may need to modify the env.shlib for your own
specific settings. See env.shlib for more details.
Some of the aws cluster operations require the setting
of a REGION name, this release attempts to retrieve
a default value. You may need to check whether that
works for you.

Please note that the worker node level auto scaling for
AWS needs more work. This release currently does not
enable this feature.
