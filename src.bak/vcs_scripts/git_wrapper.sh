#!/bin/bash
. cache
cd "$1"
if [ -n "$9" ]; then
        git "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
        exit $?
elif [ -n "$8" ]; then
        git "$2" "$3" "$4" "$5" "$6" "$7" "$8"
        exit $?
elif [ -n "$7" ]; then
        git "$2" "$3" "$4" "$5" "$6" "$7"
        exit $?
elif [ -n "$6" ]; then
        git "$2" "$3" "$4" "$5" "$6"
        exit $?
elif [ -n "$5" ]; then
        git "$2" "$3" "$4" "$5"
        exit $?
elif [ -n "$4" ]; then
        git "$2" "$3" "$4"
        exit $?
elif [ -n "$3" ]; then
        git "$2" "$3"
        exit $?
elif [ -n "$2" ]; then
        git "$2"
        exit $?
else
        echo "$0: error: no args to $0" 1>&2
        exit 1
fi

