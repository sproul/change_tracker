#!/bin/bash
stop_server=''
ct_url=http://slcipcm.us.oracle.com:4444

Start_sinatra()
{
        ruby -w $dp/git/change_tracker/src/http_handler.rb 2>&1 | sed -e '/change_tracker.*: warning/p' -e '/: warning/d' -e 's/^/SERVER: /' &
        sleep 2
}

Stop_sinatra()
{
        curl $ct_url/exit        
}


while [ -n "$1" ]; do
        case "$1" in
                -test)
                        stop_server=yes
                        ct_url=http://localhost:4567
                        Start_sinatra
                ;;
                -test_start)
                        ct_url=http://localhost:4567
                        Start_sinatra
                ;;
                *)
                        break
                ;;
        esac
        shift
done

curl $ct_url$*

if [ -n "$stop_server" ]; then
        Stop_sinatra
fi

exit
bx $dp/git/change_tracker/client_src/change_tracker.sh -test /