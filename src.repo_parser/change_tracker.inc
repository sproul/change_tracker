# as discussed at https://stackoverflow.com/questions/7772190/passing-ssh-options-to-git-clone
export GIT_SSH_COMMAND="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
# prevent env vars from seeping in and potentially influencing interactions
unset P4CLIENT
unset P4USER
unset P4PASSWD
unset P4PORT
unset P4ROOT
cd `dirname $0`
export SRC_ROOT=`pwd`
scripts_dir=$SRC_ROOT/vcs_scripts
if [ ! -d "$scripts_dir" ]; then
        echo "$0: error: could not find directory \"$scripts_dir\"" 1>&2
        exit 1
fi
export PATH=$scripts_dir:$PATH
