#!/bin/bash
# Usage: change_tracker.sh [-dry] json_path1 json_path2
# 
# Given 2 JSON files containing source control version information for each of 2 packaged products, this utility will determine the source changes that occurred between these two packages and list the changed files.

cd `dirname $0`
. change_tracker.inc

ruby -wS cli_main.rb $* 2>&1 | sed -e '/warning: setting Encoding/d' -e '/: warning: Insecure world writable dir/d'
exit
bx $dp/git/change_tracker/src/change_tracker.sh
exit
bx $dp/git/change_tracker/src/change_tracker.sh -list_changes_betweenf $dp/git/change_tracker/src/public/test_cspec_set1_v2.json $dp/git/change_tracker/src/public/test_cspec_set2_v2.json
