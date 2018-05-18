#!/bin/bash
date
verbose_mode=''
op=''
out=''

output_to_tmp_file()
{
        out=/tmp/test.out
        echo Will write voluminous output to $out
}

while [ -n "$1" ]; do
        case "$1" in
                -v)
                        verbose_mode=-v
                        output_to_tmp_file
                ;;
                -V)
                        echo Not setting verbose mode, but will buffer output, so feel free to turn on max tracing...
                        output_to_tmp_file
                ;;
                lt|ln|le)
                        op=$1
                ;;
                *)
                        break
                ;;
        esac
        shift
done
output_to_tmp_file

if [ -z "$op" ]; then
        op=-test
fi
# ct  for general access to the cli
# ctc for general access to the json interface


Ruby_change_tracker()
{
        export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=0"
        ruby -w cli_main.rb $* 2>&1 | grep -v 'warning: setting Encoding'
}

t=`mktemp`

cd `dirname $0`
SRC_ROOT=`pwd`
z=`pwd`/vcs_scripts
while [ "$z" != "/" ]; do
        chmod 755 "$z" > /dev/null 2>&1
        z=`dirname "$z"`
done

chmod 755 $SRC_ROOT
export PATH=$SRC_ROOT:$SRC_ROOT/vcs_scripts:$PATH

test_no_deps_config()
{
        cat <<EOF > $t.2.json
{
    "gitUItoCommit": "https://orahub.oraclecorp.com/faiza.bounetta/promotion-config/commit/dc68aa99903505da966358f96c95f946901c664b",
    "gitRepoName": "git@orahub.oraclecorp.com:faiza.bounetta/promotion-config.git",
    "gitBranch": "master",
    "gitCommitId": "dc68aa99903505da966358f96c95f946901c664b",
    "dependencies": [
    ]
}
EOF
cat <<EOF > $t.1.json
{
        "gitUItoCommit": "https://orahub.oraclecorp.com/faiza.bounetta/promotion-config/commit/42f2d95f008ea14ea3bb4487dba8e3e74ce992a1",
        "gitRepoName": "git@orahub.oraclecorp.com:faiza.bounetta/promotion-config.git",
        "gitBranch": "master",
        "gitCommitId": "dc68aa99903505da966358f96c95f946901c664b42f2d95f008ea14ea3bb4487dba8e3e74ce992a1",
        "dependencies": [
    ]
}
EOF
change_tracker.sh -v $t.1.json $t.2.json > $t.actual
cat <<EOF | assert.f.is "test_no_deps" $t.actual
expected output: change in  src/main/java/com/oracle/syseng/configuration/repository/IntegrationRepositoryImpl.java
EOF



}

if [ -n "$out" ]; then
        echo writing to $out ...
fi
(
cs1="git;git.osn.oraclecorp.com;osn/serverintegration;;6b5ed0226109d443732540fee698d5d794618b64+"
cs2="git;git.osn.oraclecorp.com;osn/serverintegration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e+"

case $op in
        lt)
                Ruby_change_tracker -p -ot -list_files_changed_between $cs1 $cs2
        ;;
        ln)
                Ruby_change_tracker -p -on -list_files_changed_between $cs1 $cs2
        ;;
        le)
                Ruby_change_tracker -p -oe -list_files_changed_between $cs1 $cs2
        ;;
        *)
                Ruby_change_tracker $verbose_mode $* $op
        ;;
esac
#Ruby_change_tracker -compound_commit_json_of "git;git.osn.oraclecorp.com;osn/serverintegration;;6b5ed0226109d443732540fee698d5d794618b64"
#Ruby_change_tracker -compound_commit_json_of "git;git.osn.oraclecorp.com;osn/serverintegration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
#Ruby_change_tracker -list_last_changes "git;git.osn.oraclecorp.com;osn/serverintegration;;" 500
) | if [ -n "$out" ]; then
        cat > $out
        ok_count=`grep '^OK' $out|wc -l`
        echo OK $ok_count
        grep -v '^OK' $out
else
        cat
fi
date

#test_no_deps_config
exit 0
