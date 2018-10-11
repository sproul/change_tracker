#!/bin/bash

. cache
. svn_wrapper.inc

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

# host-specific id_rsa file can be specified using .ssh/config:IdentifyFile=..., see
# https://www.digitalocean.com/community/tutorials/how-to-configure-custom-connection-options-for-your-ssh-client
#
# To request access to svn cec repo, see https://adc4110308.us.oracle.com/repos/?group=svn_idc instructions (i.e., go to oim, group_name=svn_idc)

svn $*

exit
date
$dp/git/change_tracker/src/vcs_scripts/svn_wrapper.sh "/scratch/change_tracker/svn/adc4110308.us.oracle.com/svn/idc/products/cs" log -r 159893:159898
date
