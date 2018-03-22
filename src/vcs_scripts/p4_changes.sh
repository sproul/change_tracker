#!/bin/bash
. p4.inc

p4 changes $* | sed -e '/^$/d' | tr '\n' '\t' | sed -e 's/\t\t/ /g' -e 's/\t/\n/g'

exit
$dp/git/change_tracker/src/vcs_scripts/p4_changes.sh $P4PORT $P4ROOT $P4CLIENT $P4USER "$P4PASSWD" -l -m 2 //PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities/...
