#!/bin/bash
cd `dirname $0`

# other op settings that could be used below: 
# op=list_files_changed_between
# op=list_bug_IDs_between


cat <<EOF | ruby -w ./change_tracker_http_client.rb
op=list_changes_between
cspec_set1
{
  "cspec": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;6b5ed0226109d443732540fee698d5d794618b64",
  "cspec_deps": [
    "git;git.osn.oraclecorp.com;ccs/caas;master;35f9f10342391cae7fdd69f5f8ad590fba25251d",
    "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"
  ]
}
cspec_set2
{
  "cspec_deps": [
    "git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",
    "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"
  ],
  "cspec": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
}
EOF
