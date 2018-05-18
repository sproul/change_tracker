#!/bin/bash
# get down to wherever the .svn folders are...
while [ ! -d ".svn" ]; do
        child=`ls -F | grep '/$' | head -1`
        if [ ! -d "$child" ]; then
                echo "$0: error: could not find directory \"$child\" under `pwd`" 1>&2
                exit 1
        fi
        if ! cd "$child"; then
                echo "$0: cd $child failed, exiting..." 1>&2
                exit 1
        fi
done
svn $*
exit
cd "/scratch/change_tracker/svn/adc4110308.us.oracle.com/svn/idc/products/cs";
bx $dp/git/change_tracker/src/vcs_scripts/svn_wrapper.sh log -r 159893:159898
