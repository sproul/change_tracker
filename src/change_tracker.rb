require_relative 'u'
require_relative 'error_holder'
require_relative 'file_set'
require_relative 'json_obj'
require_relative 'source_control_repo'
require_relative 'cspec'
require_relative 'cspec_set'
require 'rubygems'
require 'xmlsimple'
require 'fileutils'
require 'pp'
require 'net/http'
require 'json'

STDOUT.sync = true      # otherwise some output can get lost if there is an exception or early exit

class Change_tracker
        HOST_NAME_DEFAULT = "localhost"
        PORT_DEFAULT = 11111

        attr_accessor :host_name
        attr_accessor :port
        def initialize(host_name = Change_tracker::HOST_NAME_DEFAULT, port = Change_tracker::PORT_DEFAULT)
                self.host_name = host_name
                self.port = port.to_s
        end
        def to_s()
                "Change_tracker(#{self.host_name}:#{self.port})"
        end
        def eql?(other)
                self.host_name.eql?(other.host_name) && self.port.eql?(other.port)
        end
        class << self
        end
end

class Change_tracker_app
        attr_accessor :json_fn1
        attr_accessor :json_fn2
        
        attr_accessor :v_info1
        attr_accessor :v_info2
        
        def usage(msg)
                puts "Usage: ruby change_mon_show.rb VERSION_JSON_FILE1 VERSION_JSON_FILE2: #{msg}"
                exit
        end
        def go()
                if !json_fn1
                        usage('no args seen')
                end
                if !json_fn2
                        usage('missing VERSION_JSON_FILE2')
                end
                cspec_set1 = Cspec_set.from_file(json_fn1)
                cspec_set2 = Cspec_set.from_file(json_fn2)
                cspec_set2.list_files_added_or_updated_since(cspec_set1).each do | changed_file |
                        puts changed_file
                end
        end
end

class Global < Error_holder
        class << self
                attr_accessor :data_json_fn
                attr_accessor :data
                def init_data()
                        if !data
                                if !data_json_fn
                                        data_json_fn = "/scratch/change_tracker/change_tracker.json"
                                end
                                if File.exist?(data_json_fn)
                                        self.data = Json_obj.new(IO.read(data_json_fn))
                                else
                                        self.data = Json_obj.new
                                end
                        end
                end
                def get(key, default_value = nil)
                        init_data
                        data.get(key, default_value)
                end
                def get_scratch_dir(key)
                        raise "bad key" unless key
                        scratch_dir_root = get("scratch_dir", "/scratch/change_tracker")
                        key = key.gsub(/[^\w]/, "_")
                        scratch_dir = scratch_dir_root + "/" + key
                        FileUtils.mkdir_p(scratch_dir)
                        scratch_dir
                end
                def has_key?(key)
                        data.has_key?(key)
                end
                def get_credentials(key, ok_if_nonexistent = false)
                        u_key = "#{key}.username"
                        pw_key = "#{key}.pw"
                        if has_key?(u_key)
                                return get(u_key), get(pw_key)
                        elsif ok_if_nonexistent
                                return nil
                        else
                                raise "cannot find credentials for #{key}"
                        end
                end
                def test()
                        U.assert_eq("test.val", Global.get("test.key"), "Global.test.key")
                        U.assert_eq("default val", Global.get("test.nonexistent_key", "default val"), "Global.test.nonexistent key")
                        username, pw = Global.get_credentials("test_server")
                        U.assert_eq("some_username", username, "Global.test.username")
                        U.assert_eq("some_pw",       pw,       "Global.test.pw")
                end
        end
end

class Cec_gradle_parser < Error_holder
        def initialize()

        end
        class << self
                attr_accessor :trace_autodiscovery
                
                def to_dep_commits(gradle_deps_text, gr)
                        dependency_commits = []
                        svn_info_seen = false
                        gradle_deps_text.split(/\n/).grep(/^\s*manifest\s+"com./).each do | raw_manifest_line |

                                # raw_manifest_line=  manifest "com.oracle.cecs.caas:manifest:1.master_external.528"         //@trigger
                                puts "Cec_gradle_parser.to_dep_commits: raw_manifest_line=#{raw_manifest_line}" if trace_autodiscovery
                                
                                pom_url = Cec_gradle_parser.generate_manifest_url(raw_manifest_line)
                                puts "Cec_gradle_parser.to_dep_commits: resolved to pom_url=#{pom_url}" if trace_autodiscovery
                                pom_content = U.rest_get(pom_url)
                                puts "Cec_gradle_parser.to_dep_commits: ready to parse pom_content=#{pom_content}" if trace_autodiscovery
                                h = XmlSimple.xml_in(pom_content)
                                # {"git.repo.name"=>["caas.git"], "git.repo.branch"=>["master_external"], "git.repo.commit.id"=>["90f08f6882382e0134191ca2a993191c2a2f5b48"], "git.commit-id"=>["caas.git:90f08f6882382e0134191ca2a993191c2a2f5b48"], "jenkins.git-branch"=>["master_external"], "jenkins.build-url"=>["https://osnci.us.oracle.com/job/caas.build.pl.master_external/528/"], "jenkins.build-id"=>["2018-02-16_21:51:53"]}
                                puts %Q[Cec_gradle_parser.to_dep_commits: parsed pom xml, and seeing h["properties"][0]=#{h["properties"][0]}] if trace_autodiscovery
                                repo_parent = h["properties"][0]
                                if repo_parent.has_key?("git.repo.name")
                                        git_project_basename = repo_parent["git.repo.name"][0] # e.g., caas.git
                                elsif repo_parent.has_key?("svn.repo.name")
                                        # example:
                                        # <properties>
                                        #    <svn.repo.name>adc4110308.us.oracle.com/svn/idc/products/cs</svn.repo.name>
                                        #    <svn.repo.branch>cloudtrunk-externalcompute</svn.repo.branch>
                                        #    <svn.repo.revision>159788</svn.repo.revision>
                                        #    <jenkins.build-url>https://osnci.us.oracle.com/job/docs.build.pl.master_external/638/</jenkins.build-url>
                                        #    <jenkins.build-id>638</jenkins.build-id>
                                        # </properties>
                                        svn_repo_name = repo_parent["svn.repo.name"]
                                        svn_info_seen = true
                                        svn_branch = repo_parent["svn.repo.branch"]
                                        svn_commit_id = repo_parent["svn.repo.revision"]
                                        puts "svn_repo_name=#{svn_repo_name}, svn_branch=#{svn_branch}, svn_commit_id=#{svn_commit_id}, but not implemented yet" # if trace_autodiscovery
                                        next        # svn not supported yet
                                else
                                        puts "not sure what this repo_parent is:"
                                        pp repo_parent
                                        next
                                end
                                git_repo_branch = h["properties"][0]["git.repo.branch"][0]
                                git_repo_commit_id = h["properties"][0]["git.repo.commit.id"][0]

                                if git_project_basename == "caas.git"
                                        repo_name = "ccs/#{git_project_basename}"
                                else
                                        repo_name = "#{gr.get_project_name_prefix}/#{git_project_basename}"
                                end
                                repo_name.sub!(/.git$/, '')
                                repo_spec = Repo.make_spec(gr.source_control_server, repo_name, git_repo_branch)
                                dependency_commit = Cspec.new(repo_spec, git_repo_commit_id)
                                dependency_commits << dependency_commit
                                dependency_commits += dependency_commit.unreliable_autodiscovery_of_dependencies_from_build_configuration
                                
                                puts "Cec_gradle_parser.to_dep_commits: dep repo_name=#{repo_name} (commit #{git_repo_commit_id}), resolved to dep #{dependency_commit}" if trace_autodiscovery

                                # jenkins.git-branch # master_external
                                # jenkins.build-url # https://osnci.us.oracle.com/job/infra.social.build.pl.master_external/270/
                                # jenkins.build-id # 270
                        end
                        if dependency_commits.empty? && !svn_info_seen
                                raise "could not find deps in #{gradle_deps_text}"
                        end
                        dependency_commits
                end
                def generate_manifest_url(raw_manifest_line)
                        z = raw_manifest_line.sub(/  *manifest \"/, '')
                        z.sub!(/\/\/.*/, '')
                        z.sub!(/" *$/, '')

                        if z !~ /^(.*?):manifest:(\d+)\.([^\.]+)\.(\d+)$/
                                raise "could not understand #{z}"
                        end
                        package = $1
                        n1 = $2.to_i
                        branch = $3
                        n2 = $4.to_i

                        component = package.sub(/.*\./, '')

                        if branch == "master_internal"
                                top_package_components = "socialnetwork/#{component}"
                        else
                                top_package_components = "cecs/#{component}"
                        end
                        "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/#{top_package_components}/manifest/#{n1}.#{branch}.#{n2}/manifest-#{n1}.#{branch}.#{n2}.pom"
                end
                def test_manifest_parse(raw_manifest_line, expected_generated_manifest_url)
                        actual_generated_manifest_url = generate_manifest_url(raw_manifest_line)
                        pom_content = U.rest_get(actual_generated_manifest_url)
                        if pom_content =~ /"status" : 404,/
                                puts "I mapped the manifest line"
                                puts "\t#{raw_manifest_line}\nto\n\t#{actual_generated_manifest_url}"
                                if expected_generated_manifest_url =~ /^http/
                                        puts "but\n\t#{expected_generated_manifest_url}\nworks."
                                end
                                puts ""
                                puts ""
                                raise "did not find dependency for\n#{actual_generated_manifest_url}\nfrom\n#{raw_manifest_line}\n(#{pom_content})"
                        end
                        U.assert_eq(expected_generated_manifest_url, actual_generated_manifest_url, "generated_manifest_url #{raw_manifest_line}")
                end
                def test()
                        test_manifest_parse("  manifest \"com.oracle.cecs.waggle:manifest:1.master_external.222\"         //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/cecs/waggle/manifest/1.master_external.222/manifest-1.master_external.222.pom")
                        test_manifest_parse("  manifest \"com.oracle.cecs.docs-server:manifest:1.master_external.94\"         //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/cecs/docs-server/manifest/1.master_external.94/manifest-1.master_external.94.pom")
                        test_manifest_parse("  manifest \"com.oracle.cecs.caas:manifest:1.master_external.53\"         //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/cecs/caas/manifest/1.master_external.53/manifest-1.master_external.53.pom")
                        test_manifest_parse("  manifest \"com.oracle.cecs.analytics:manifest:1.master_external.42\"         //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/cecs/analytics/manifest/1.master_external.42/manifest-1.master_external.42.pom")
                        test_manifest_parse("  manifest \"com.oracle.cecs.servercommon:manifest:1.master_external.74\"     //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/cecs/servercommon/manifest/1.master_external.74/manifest-1.master_external.74.pom")
                        test_manifest_parse("  manifest \"com.oracle.cecs.waggle:manifest:1.master_external.270\"         //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/cecs/waggle/manifest/1.master_external.270/manifest-1.master_external.270.pom")
                        test_manifest_parse("  manifest \"com.oracle.cecs.docs-server:manifest:1.master_external.156\"         //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/cecs/docs-server/manifest/1.master_external.156/manifest-1.master_external.156.pom")
                        test_manifest_parse("  manifest \"com.oracle.cecs.caas:manifest:1.master_external.126\"         //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/cecs/caas/manifest/1.master_external.126/manifest-1.master_external.126.pom")
                        test_manifest_parse("  manifest \"com.oracle.cecs.analytics:manifest:1.master_external.84\"         //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/cecs/analytics/manifest/1.master_external.84/manifest-1.master_external.84.pom")
                        test_manifest_parse("  manifest \"com.oracle.cecs.servercommon:manifest:1.master_external.137\"     //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/cecs/servercommon/manifest/1.master_external.137/manifest-1.master_external.137.pom")
                        test_manifest_parse("  manifest \"com.oracle.cecs.pipeline-common:manifest:1.master_external.4\" //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/cecs/pipeline-common/manifest/1.master_external.4/manifest-1.master_external.4.pom")
                        test_manifest_parse("  manifest \"com.oracle.socialnetwork.pipeline-common:manifest:1.master_internal.55\" //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/socialnetwork/pipeline-common/manifest/1.master_internal.55/manifest-1.master_internal.55.pom")
                        test_manifest_parse("  manifest \"com.oracle.socialnetwork.webclient:manifest:1.master_internal.8103\"         //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/socialnetwork/webclient/manifest/1.master_internal.8103/manifest-1.master_internal.8103.pom")
                        test_manifest_parse("  manifest \"com.oracle.socialnetwork.officeaddins:manifest:1.master_internal.161\"         //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/socialnetwork/officeaddins/manifest/1.master_internal.161/manifest-1.master_internal.161.pom")
                        test_manifest_parse("  manifest \"com.oracle.socialnetwork.cef:manifest:1.master_internal.3790\"         //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/socialnetwork/cef/manifest/1.master_internal.3790/manifest-1.master_internal.3790.pom")
                        test_manifest_parse("  manifest \"com.oracle.socialnetwork.caas:manifest:1.master_internal.2364\"        //@trigger", "https://af.osn.oraclecorp.com/artifactory/internal-local/com/oracle/socialnetwork/caas/manifest/1.master_internal.2364/manifest-1.master_internal.2364.pom")
                end
        end
end
