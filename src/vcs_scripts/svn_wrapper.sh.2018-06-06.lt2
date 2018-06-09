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

# this is for memoization to work -- this is a crucial input
wd=`pwd`
export CACHE_EXTRA_ARG=`ls --inode "$wd"`
. cache

svn $*
exit
cd "/scratch/change_tracker/svn/adc4110308.us.oracle.com/svn/idc/products/cs";
date
$dp/git/change_tracker/src/vcs_scripts/svn_wrapper.sh log -r 159893:159898
date
