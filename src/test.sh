#!/bin/bash
Ruby_change_tracker()
{
        export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=0"
        ruby -w cli_main.rb $* 2>&1 | grep -v 'warning: setting Encoding'
}

t=`mktemp`

export PATH=`dirname $0`:$PATH

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

Ruby_change_tracker -test
#Ruby_change_tracker -list_changes_between "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64" "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
#Ruby_change_tracker -compound_commit_json_of"git;git.osn.oraclecorp.com;osn/cec-server-integration;;;2bc0b1a58a9277e97037797efb93a2a94c9b6d99"
#test_no_deps_config
exit 0
