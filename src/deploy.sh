#!/bin/bash
while [ -n "$1" ]; do
        case "$1" in
                -prod)
                        echo Deploying to production.  Copying 
                ;;
                *)
                        break
                ;;
        esac
        shift
done

sudo gem install xml-simple
sudo gem install sinatra -v 1.4.4       # newer sinatra seems to need ruby 2.2
ct_root=/scratch/change_tracker
f=$ct_root/change_tracker.json
sudo mkdir $ct_root
mkdir $ct_root/log
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
bx $dp/git/change_tracker/src/deploy.sh 