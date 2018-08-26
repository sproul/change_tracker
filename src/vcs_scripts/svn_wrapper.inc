# from discussion of how to call a particular (not necessarily default) ssh key for use w/ svn at
# https://stackoverflow.com/questions/192134/how-do-i-get-a-svn-checkout-using-a-public-private-key-pair
export SVN_SSH="ssh -i $dp/home/.ssh/svn/id_rsa"
