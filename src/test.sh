#!/bin/bash
t=`mktemp`

Ruby_change_tracker()
{
        ruby -w change_tracker.rb $* 2>&1 | grep -v 'warning: setting Encoding'
}

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
#test_no_deps_config
exit 0
