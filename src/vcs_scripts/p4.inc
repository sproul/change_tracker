# this must agree w/ the arguments laid out in P4_version_control_system.prepend_p4_var_settings in version_control_system.rb:
P4CLIENT=$1
shift
P4USER=$1
shift
P4PASSWD="$1"
shift
P4ROOT=$1
shift
if [ ! -d "$P4ROOT" ]; then
        echo "$0: error: could not find P4ROOT directory \"$P4ROOT\"" 1>&2
        exit 1
fi
P4ROOT=$1
shift

# to avoid those 
# Path '/home/nsproul/dp/git/change_tracker/src/2' is not under client's root '/home/nsproul/p4'
# errors:
cd "$P4ROOT"
