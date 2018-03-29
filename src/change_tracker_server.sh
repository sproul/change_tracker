#!/bin/bash -x

cd `dirname $0`
. change_tracker.inc

unset HTTP_PROXY
unset http_proxy
unset HTTPS_PROXY
unset https_proxy

stop_server_on_exit=''
ct_url=http://localhost:4567
if [ -z "$ct_root" ]; then
        ct_root=$dp/git/change_tracker
fi

Start_sinatra_logged()
{
        # so as to show exceptions.  "production" is the alternative, which suppresses debug info
        export APP_ENV=development
        
        echo Logging activity to stdout and $log_fn...
        ruby -w $ct_root/src/http_handler.rb 2>&1 | sed -e  '/warning: setting Encoding/d' -e '/change_tracker.*: warning/p' -e '/: warning/d' >> $log_fn
}

while [ -n "$1" ]; do
        case "$1" in
                --Start_sinatra_logged)
                        Start_sinatra_logged
                        exit
                ;;
                *)
                        break
                ;;
        esac
        shift
done

Start_sinatra()
{
        export log_root=$ct_root/log
        mkdir -p $log_root
        export log_fn=$log_root/out.`date +'%a'`
        touch $log_fn
        nohup $0 --Start_sinatra_logged 2>&1 >> $log_root/nohup.out &
        tail -f $log_fn | sed -e 's/^/SERVER: /' &
}

Stop_sinatra()
{
        curl $ct_url/exit
}


while [ -n "$1" ]; do
        case "$1" in
                -test)
                        stop_server_on_exit=yes
                        Stop_sinatra
                        sleep 2
                        Start_sinatra
                ;;
                0)
                        Stop_sinatra
                        exit
                ;;
                1)
                        Start_sinatra &
                        exit
                ;;
                *)
                        break
                ;;
        esac
        shift
done

curl $ct_url$*

if [ -n "$stop_server_on_exit" ]; then
        sleep 2
        Stop_sinatra
fi

exit
bx $dp/git/change_tracker/client_src/change_tracker_server.sh -test /