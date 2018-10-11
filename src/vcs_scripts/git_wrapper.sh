#!/bin/bash
#echo $0 $*; echo $dp/git/change_tracker/src/vcs_scripts/git_wrapper.sh EXITING early; exit

. cache

no_retry_mode=''
while [ -n "$1" ]; do
        case "$1" in
                -no_retry)
                        export no_retry_mode=yes
                ;;
                *)
                        break
                ;;
        esac
        shift
done

cd "$1"
shift

t=$TMP/git_wrapper.sh.$$
trap "rm $t" EXIT

# yes, agreed that this is awful.  Did it this way to avoid trouble w/ quoted args where the quotes must be preserved.
if [ -n "$9" ]; then
        git "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
elif [ -n "$8" ]; then
        git "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8"
elif [ -n "$7" ]; then
        git "$1" "$2" "$3" "$4" "$5" "$6" "$7"
elif [ -n "$6" ]; then
        git "$1" "$2" "$3" "$4" "$5" "$6"
elif [ -n "$5" ]; then
        git "$1" "$2" "$3" "$4" "$5"
elif [ -n "$4" ]; then
        git "$1" "$2" "$3" "$4"
elif [ -n "$3" ]; then
        git "$1" "$2" "$3"
elif [ -n "$2" ]; then
        git "$1" "$2"
elif [ -n "$1" ]; then
        git "$1"
else
        echo "$0: error: no args to $0" 1>&2
        exit 1
fi > $t 2> $t.err
rc=$?
if [ rc == 0 ]; then
        cat $t
        cat $t.err 1>&2
        exit 0
fi
if ! grep 'fatal: Invalid revision range' $t.err > /dev/null; then
        cat $t  # failed, not sure why, just send the error output along...
        cat $t.err 1>&2
else
        # This indicates that there was a reference to history that came after the head of the local copy; pull again and retry:
        git pull origin master > /dev/null # must be silent to avoid confusing caller with output not related to the immediate op (e.g., 'log')
        if [ -n "$9" ]; then
                git "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"  
        elif [ -n "$8" ]; then
                git "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8"  
        elif [ -n "$7" ]; then
                git "$1" "$2" "$3" "$4" "$5" "$6" "$7"  
        elif [ -n "$6" ]; then
                git "$1" "$2" "$3" "$4" "$5" "$6"  
        elif [ -n "$5" ]; then
                git "$1" "$2" "$3" "$4" "$5"  
        elif [ -n "$4" ]; then
                git "$1" "$2" "$3" "$4"  
        elif [ -n "$3" ]; then
                git "$1" "$2" "$3"  
        elif [ -n "$2" ]; then
                git "$1" "$2"  
        elif [ -n "$1" ]; then
                git "$1"  
        else
                echo "$0: error: no args to $0" 1>&2
                exit 1
        fi
        exit $?
fi
exit $rc


exit
bash $dp/git/change_tracker/src/vcs_scripts/git_wrapper.sh /scratch/change_tracker/git/git.osn.oraclecorp.com/osn/cec_external log "--pretty=format:%H %s" f2cedfe8a577962ccd8d03150ca3ec9b56ed73aa..2e32f0fe364f0853c52a031791ccf9aab56f53aa
echo $?
