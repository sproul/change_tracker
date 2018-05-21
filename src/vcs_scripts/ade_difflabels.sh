#!/bin/bash
. cache
labellog1=$1
labellog2=$2
ade difflabels -old_emd $labellog1 -new_emd $labellog2 -product_only | grep -v WARNING
exit
$dp/git/change_tracker/src/vcs_scripts/ade_difflabels.sh /ade_autofs/gd59_fmw/PCBPEL_ICSMAIN_GENERIC.rdd/180505.0743.0980/.labellog.emd.gz /ade_autofs/gd59_fmw/PCBPEL_ICSMAIN_GENERIC.rdd/180515.1831.0993/.labellog.emd.gz
