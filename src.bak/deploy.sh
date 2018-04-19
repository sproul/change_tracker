#!/bin/bash
if [ -z "$ct_root" ]; then
        echo "$0: error: expected a value for \"ct_root\" but saw nothing" 1>&2
        exit 1
fi

from_ct_root_src=`dirname $0`
if [ "$from_ct_root_src" = "." ]; then
        from_ct_root_src=`pwd`
fi
ct_root_src=$ct_root/src

if ! which pleaserun > /dev/null 2>&1; then
        if ! sudo gem install pleaserun; then
                echo "$0: sudo gem install pleaserun failed, exiting..." 1>&2
                exit 1
        fi
        sudo /usr/sbin/useradd -s/bin/bash -b /scratch -m change_tracker
        sudo gem install xml-simple
        sudo gem install sinatra -v 1.4.4       # newer sinatra seems to need ruby 2.2
        ruby=`which ruby`
        if [ -z "$ruby" ]; then
                echo "$0: error: expected to be able to find ruby, but I do not see it on the PATH ($PATH)" 1>&2
                exit 1
        fi
        ruby_bin=`dirname $ruby`
        
        command_to_run=$ct_root_src/change_tracker_server.sh
        sudo pleaserun --install --user change_tracker --name change_tracker --description 'Run application to report on changes made between software revisions' $command_to_run
        cat <<EOF > /etc/default/change_tracker
        :
        export op=\${1-start}
        (
        export PATH=$ruby_bin:\$PATH
        export ct_root=/scratch/change_tracker
        cd \$ct_root/src
        bash -x ./change_tracker_server.sh \$op
        ) > /var/log/change_tracker_start.log
        EOF
        chmod +x /etc/default/change_tracker
fi

f=$ct_root/change_tracker.json
sudo mkdir $ct_root
mkdir $ct_root/log
sudo touch $f
sudo c7    $f
rm -rf $ct_root_src.bak
mv     $ct_root_src $ct_root_src.bak
echo "cp -pr  $from_ct_root_src $ct_root_src"
cp       -pr  $from_ct_root_src $ct_root_src
cat <<EOF > $f
{
    "test_server.username" : "some_username",
    "test_server.pw" : "some_pw",
    "test.key" : "test.val"
}
EOF
cat $f
sudo start change_tracker
sleep 2
tail /var/log/change_tracker-stderr.log

exit
bx $dp/git/change_tracker/src/deploy.sh 