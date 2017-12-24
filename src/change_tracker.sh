#!/bin/bash
# Given 2 JSON files containing source control version information for each of 2 packaged products, this utility will determine the source changes that occurred between these two packages and list the changed files.

json_fn1="$1"
json_fn2="$2"


if [ ! -f "$json_fn1" ]; then
        echo "$0: expected file at \"$json_fn1\"" 1>&2
        exit 1
fi

if [ ! -f "$json_fn2" ]; then
        echo "$0: expected file at \"$json_fn2\"" 1>&2
        exit 1
fi

ruby -wS change_tracker.rb "$json_fn1" "$json_fn2" 2>&1 | grep -v 'warning: setting Encoding'
exit
bx $dp/git/change_tracker/src/change_tracker.sh 
