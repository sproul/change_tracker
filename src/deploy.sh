#!/bin/bash
sudo gem install xml-simple
sudo gem install sinatra -v 1.4.4       # newer sinatra seems to need ruby 2.2
f=/scratch/change_tracker.json
sudo touch $f
sudo c7    $f
cat <<EOF > $f
{
    "@@" : "@@",
    "@@" : "@@",
    "@@" : "@@",
    "@@" : "@@",
    "test_server.username" : "some_username",
    "test_server.pw" : "some_pw",
    "test.key" : "test.val"
}
EOF
cat $f
exit