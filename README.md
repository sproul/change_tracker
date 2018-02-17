change_tracker: utility to describe file differences between two versions of software

A common question when working with a series of versions of some software is what source files changed between versions? This question can be complicated when the software is composed by multiple components whose source code lines are hosted by multiple source control systems. To provide a basis for answering this type of question, we have an evolving standard for describing in JSON where a component came from, as exemplified by the following:

{
    "groupId": "",
    "artifactId": "prototype",
    "version": "unspecified",
    "packaging": "zip",
    "description": "null",
    "change_tracker": "slc15mno:11022",
    "gitRepoName": "ALM:mcs_mobile-cloud-service/mobile-core.git",
    "gitRepoBranch": "feature_artifactDescriptor",
    "gitRepoCommitId": "202678da87709d57abbee18c83ad64e91d57bddc",
    "jenkinsBuildUrl": "null",
    "jenkinsBuildId": "null",
    "dependencies": [
            "dep1_abc" : {
                "groupId": "",
                "artifactId": "dep1_abc_prototype",
                "version": "unspecified",
                "packaging": "zip",
                "description": "null",
                "change_tracker": "slc15abc:11022",
                "gitRepoName": "ALM:dep1_alm_name/abc.git",
                "gitRepoBranch": "dep1_feature_artifactDescriptor",
                "gitRepoCommitId": "1111111111111222222222222222333333333333",
                "jenkinsBuildUrl": "null",
                "jenkinsBuildId": "null"
            },
            "dep1_xyz" : {
                "groupId": "",
                "artifactId": "dep1_xyz_prototype",
                "version": "unspecified",
                "packaging": "zip",
                "description": "null",
                "change_tracker": "slc15xyz:11022",
                "gitRepoName": "ALM:dep1_alm_name/xyz.git",
                "gitRepoBranch": "dep1_feature_artifactDescriptor",
                "gitRepoCommitId": "3333444444444444444444444444455555555555",
                "jenkinsBuildUrl": "null",
                "jenkinsBuildId": "null"
            }
        ]
}

The key elements here are the
 change_tracker: a host/port pair telling where we can find a running instance of the change_tracker software which is aware of what credentials needed to access the associated source control system
 gitRepoName: the git repo name
 gitRepoBranch: the git repo branch
 gitRepo: the git repo

For the change_tracker software, there are essentially two roles:
1.) Resolve where to find a change_tracker instance capable of answering a question concerning a specific source control system
2.) Given a particular source control system, answer a question requiring credentials to access that system

This division is driven by the need to avoid forcing development groups to share their credentials outside of their own organization. The thought is that we can run an instance of the change_tracker software which would then query as needed other instances of change_tracker software controlled by the various development groups. The first instance of the change_tracker software would not be aware of the source control system credentials, but this second group of change_tracker instances would be controlled by the development groups and would be aware of what credentials were needed to access those same groups' source control systems in order to answer questions.

Initially the only question that we will support will be "what files have changed between version X and version Y?"

So to step through the base use scenario for the sample data above corresponding to a version X of some software, imagine JSON describing version Y of the same software:
{
    "groupId": "",
    "artifactId": "prototype",
    "version": "unspecified",
    "packaging": "zip",
    "description": "null",
    "change_tracker": "slc15mno:11022",
    "gitRepoName": "ALM:mcs_mobile-cloud-service/mobile-core.git",
    "gitRepoBranch": "feature_artifactDescriptor",
    "gitRepoCommitId": "111111111111111111112222222222222222",
    "jenkinsBuildUrl": "null",
    "jenkinsBuildId": "null",
    "dependencies": [
            "dep1_abc" : {
                "groupId": "",
                "artifactId": "dep1_abc_prototype",
                "version": "unspecified",
                "packaging": "zip",
                "description": "null",
                "change_tracker": "slc15abc:11022",
                "gitRepoName": "ALM:dep1_alm_name/abc.git",
                "gitRepoBranch": "dep1_feature_artifactDescriptor",
                "gitRepoCommitId": "1111111111111222222222222222333333333300",
                "jenkinsBuildUrl": "null",
                "jenkinsBuildId": "null"
            },
            "dep1_xyz" : {
                "groupId": "",
                "artifactId": "dep1_xyz_prototype",
                "version": "unspecified",
                "packaging": "zip",
                "description": "null",
                "change_tracker": "slc15xyz:11022",
                "gitRepoName": "ALM:dep1_alm_name/xyz.git",
                "gitRepoBranch": "dep1_feature_artifactDescriptor",
                "gitRepoCommitId": "3333444444444444444444444444455555555500",
                "jenkinsBuildUrl": "null",
                "jenkinsBuildId": "null"
            }
        ]
}

Note that in this case the JSON is similar except that the gitRepoCommitId values differ. (We will eventually support other interesting differences like having different branch names, and having supper components whose source is stored in source control systems besides git.)

So for the JSON sample data for versions X and Y, the initial question would be routed to a change_tracker hosted at slc15mno:11022. This change_tracker instance would determine what files had changed between getRepoCommitId 111111111111111111112222222222222222 and 202678da87709d57abbee18c83ad64e91d57bddc. Then looking at the dependencies, change_tracker would see that there were other source control components which changed as well, namely dep1_abc and dep1_xyz. For dep1_abc, the question of which files had changed would be forwarded to the change_tracker instance running at slc15abc:11022.  For the dependency dep1_xyz, the same question would be forwarded to the change_tracker instance running at slc15xyz:11022.  The results to these two queries would be combined with the file differences for the top-level component and returned to the caller as a unit.

To minimize redundancy, the tool will support "including" JSON via URL. For the JSON describing version Y above, this technique would shorten and simplify the dependencies as shown below:

{
    "groupId": "",
    "artifactId": "prototype",
    "version": "unspecified",
    "packaging": "zip",
    "description": "null",
    "change_tracker": "slc15mno:11022",
    "gitRepoName": "ALM:mcs_mobile-cloud-service/mobile-core.git",
    "gitRepoBranch": "feature_artifactDescriptor",
    "gitRepoCommitId": "111111111111111111112222222222222222",
    "jenkinsBuildUrl": "null",
    "jenkinsBuildId": "null",
    "dependencies": [
            "dep1_abc" : "http://some_oracle_server/dep1_abc.json",
            "dep1_xyz" : "http://some_oracle_server/dep1_xyz.json"
        ]
}


The objects used to model the problem:

class Change_tracker -- a Change_tracker instance runs on a host and is aware of some set of source control creds
class Git_repo -- a source control server for which we have credentials
class Git_commit -- a commit point for a particular git controlled product
class Compound_commit -- a set of commits (normally a top level product and its dependencies)
class Change_tracker_app -- answers questions by relaying queries to Change_tracker instances (possibly itself) as needed


Yes.   They all follow a certain pattern.  This resolves to:

https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/cecs/servercommon/manifest/1.master_external.4/manifest-1.master_external.4.pom

which no longer exists -- this is quite old.   a newer version can be found at:

https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/cecs/servercommon/manifest/1.master_external.274/manifest-1.master_external.274.pom

replace 'servercommon' with the component name, master_external with the branch name, and '274' with the version in deps.gradle for different POMs.

-Steve
On 02/07/2018 10:34 PM, Nelson Sproul wrote:
Here