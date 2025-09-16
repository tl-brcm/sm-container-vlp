# examples/cpgitbranch -- copy git branch from one repo to another
* WARNING:
	* if the destination repo contains the same branch
	* before this operation, the original content will be
	* removed first before receiving the new data from the source

This example copies a branch (GITBRANCH) on a git repository (GITFBASE)
to a branch of the same name on another git repository (GITTBASE).

If the destination branch exists already, it will be deleted first.
The result branch will be pushed to the git server. A local copy of the
branch is kept with two remotes attached.

See env.shlib for configuration
