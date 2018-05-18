#!/bin/bash

if [ -z "$JAVA_HOME" ]; then
        echo "$0: expected a value for \"JAVAHOME\" but saw nothing" 1>&2
        exit 1
fi
if ! which javac > /dev/null 2>&1; then
        echo "$0: which javac failed, exiting..." 1>&2
        exit 1
fi
if ! which java > /dev/null 2>&1; then
        echo "$0: which java failed, exiting..." 1>&2
        exit 1
fi
cd `dirname $0`
javac ChangeTracker.java
export CLASSPATH=.
java  ChangeTracker

exit
$dp/git/change_tracker/src/public/samples/java/execute.sh 