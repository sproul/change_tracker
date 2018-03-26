#!/bin/bash
export P4CLIENT=$1
shift
export P4USER=$1
shift
export P4PASSWD="$1"
shift
export P4ROOT="$1"
shift
export P4PORT=$1
shift

if [ ! -d "$P4ROOT" ]; then
        echo "$0: error: could not find P4ROOT directory \"$P4ROOT\"" 1>&2
        exit 1
fi
cd "$P4ROOT"

$*

exit $?