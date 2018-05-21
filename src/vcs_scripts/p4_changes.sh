#!/bin/bash

p4 changes $* | sed -e '/^$/d' | tr '\n' '\t' | sed -e 's/\t\t/ /g' -e 's/\t/\n/g'

exit $?
$dp/git/change_tracker/src/vcs_scripts/p4_changes.sh -l -m 2 //PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities/...
exit
date
$dp/git/change_tracker/src/vcs_scripts/p4_changes.sh  //PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities/...@121159,129832
date
