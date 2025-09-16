# examples/crgitcomb - config retreiver git branches combine utility
This example uses a base git branch (GITFROM) and cherry-picks commits from 
the very last commit of other branches (GITCHERRIES) to create a new branch
(GITTO). Only the very last commit of each of the specified branches
will be cherry-pikced to create the new branch.

If the destination branch exists already, it will be deleted first.
The result branch will be pushed to the git server. A local copy of the
result branch is kept.

If there are more than one commits from any of the branch are needed,
they need to be combined into the last commit within the branch.

See env.shlib for details about configuring each variable.
