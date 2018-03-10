#!/bin/bash
# Usage: change_tracker.sh [-dry] json_fn1 json_fn2
# 
# Given 2 JSON files containing source control version information for each of 2 packaged products, this utility will determine the source changes that occurred between these two packages and list the changed files.

# as discussed at https://stackoverflow.com/questions/7772190/passing-ssh-options-to-git-clone
export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

cd `dirname $0`
ruby -wS change_tracker.rb $* 2>&1 | sed -e '/warning: setting Encoding/d' -e '/: warning: Insecure world writable dir/d'
exit
bx $dp/git/change_tracker/src/change_tracker.sh 
