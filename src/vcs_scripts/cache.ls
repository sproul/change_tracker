#!/bin/bash
search_args=$*

if [ -z "$search_args" ]; then
        search_args=.
fi

for cf in `ls $TMP/cache.*.cmd | sed -e 's/\.cmd$//'`; do
        if cat $cf.cmd | grepm $search_args; then
                cat $cf
                echo EOD
                echo "cache.get $cf"
                echo '----------------------------------------------------------------------------------------------'
        fi
done

exit
cd $dp/git/change_tracker/src/test/cache_seed/
$dp/bin/cache.ls describe
