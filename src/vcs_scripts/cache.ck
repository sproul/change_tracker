#!/bin/bash
cd $TMP
out=`mktemp`
trap "rm $out" EXIT

for f in *.cmd; do
        f=`sed -e 's/.cmd$//' <<< $f`
        honk checking $f
        `cat $f.cmd` > $out
        echo.clean "diff $f $out"
        if ! diff $f $out; then
                echo "$0: diff $f $out mismatch" 1>&2
        fi
done

exit
$dp/bin/cache.ck 