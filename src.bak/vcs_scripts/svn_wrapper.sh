#!/bin/bash

. cache
dir="$1"
cd "$dir"
shift

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
date
$dp/git/change_tracker/src/vcs_scripts/svn_wrapper.sh "/scratch/change_tracker/svn/adc4110308.us.oracle.com/svn/idc/products/cs" log -r 159893:159898
date
