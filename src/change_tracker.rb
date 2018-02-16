require_relative 'u'
require 'rubygems'
require 'xmlsimple'
require 'fileutils'
require 'pp'
require 'net/http'
require 'json'

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

class Git_repo
        attr_accessor :project_name
        attr_accessor :global_data_prefix
        attr_accessor :branch_name
        attr_accessor :source_control_server
        
        def initialize(spec)
                source_control_type, source_control_server, project_name, branch_name = spec.split(/;/)
                if source_control_type != "git"
                        raise "unexpected source_control_type #{source_control_type}"
                end
                if branch_name == ""
                        self.branch_name = nil
                else
                        self.branch_name = branch_name
                end
                self.project_name = project_name
                self.global_data_prefix = "git_repo_#{project_name}."
                self.source_control_server = source_control_server
                if !Git_repo.codeline_root_parent
                        Git_repo.codeline_root_parent = Global.get_scratch_dir(self.project_name)
                end 
        end
        def to_s()
                "Git_repo(#{project_name}"
        end
        def eql?(other)
                self.project_name.eql?(other.project_name)
        end
        def get(key, default_val=nil)
                Global.get(self.global_data_prefix + key, default_val)
        end
        def get_file(path)
                fn = "#{Git_repo.codeline_root_parent}/#{self.project_name}/#{path}"
                if !File.exist?(fn)
                        raise "could not read #{fn}"
                end
                IO.read(fn)
        end
        def write_codeline_to_disk(branch, commit_id)
                username = self.get("#{source_control_server}.username")
                pw       = self.get("#{source_control_server}.pw")
                if Dir.entries(Git_repo.codeline_root_parent).size == 2 # only contains ., ..
                        git_url = "https://#{username}:#{pw}@#{self.source_control_server}/#{project_name}.git"
                        puts git_url
                        exit
                        U.system("git clone #{git_url}", nil, codeline_root_parent)
                end
                dir = U.only_child_of(codeline_root_parent)
                if Dir.entries(dir).size == 2
                        raise "error: expected #{dir} to be populated after cloning"
                end
                dir
        end
        class << self
                attr_accessor :codeline_root_parent
                def test()
                        gr = Git_repo.new("git;osn.oraclecorp.com:cec-server-integration;;")
                        gr.write_codeline_to_disk
                        deps_gradle_content = gr.get_file("deps.gradle")
                        manifest_lines = deps_gradle_content.split("\n").grep(/manifest/)
                        U.assert(manifest_lines.size > 1)
                end
        end
end

class Json_obj
        attr_accessor :h
        def initialize(json_text = nil)
                if json_text
                        self.h = JSON.parse(json_text)
                else
                        self.h = Hash.new
                end
        end
        def to_s()
                "Json_obj(#{self.h})"
        end
        def get(key, default_val = nil)
                if !self.h.has_key?(key)
                        if default_val
                                return default_val
                        else
                                raise "no match for key #{key} in #{self.h}"
                        end
                end
                h[key]
        end
end


class Git_commit
        attr_accessor :change_tracker
        attr_accessor :repo
        attr_accessor :branch
        attr_accessor :commit_id
        def initialize(change_tracker, repoName, branch, commit_id)
                self.change_tracker = change_tracker
                self.repo = Git_repo.new(repoName)
                self.branch = branch
                self.commit_id = commit_id
        end
        def eql?(other)
                other && self.change_tracker.eql?(other.change_tracker) && self.repo.eql?(other.repo) && self.branch.eql?(other.branch) && self.commit_id.eql?(other.commit_id)
        end
        def to_s()
                "Git_commit(#{self.change_tracker}, #{self.repo}, #{self.branch}, #{self.commit_id})"
        end
        def to_json()
                z = "{"
                z << Json_obj.format_pair("change_tracker", self.change_tracker) << ","
                z << Json_obj.format_pair("repo_name", self.repo.name) << ","
                z << Json_obj.format_pair("branch_name", self.branch) << ","
                z << Json_obj.format_pair("commit_id", self.commit_id)
                z << "}"
                z
        end
        def write_codeline_to_disk()
                repo.write_codeline_to_disk(self.branch, self.commit_id)
        end
        def component_contained_by?(compound_commit)
                self.find_commit_for_same_component(compound_commit) != nil
        end
        def repo_system_as_list(cmd)
                local_codeline_root_dir = self.write_codeline_to_disk
                U.system_as_list(cmd, nil, local_codeline_root_dir)
        end
        def list_files_added_or_updated()
                # https://stackoverflow.com/questions/424071/how-to-list-all-the-files-in-a-commit
                repo_system_as_list("git diff-tree --no-commit-id --name-only -r #{self.commit_id}")
        end
        def list_files()
                # https://stackoverflow.com/questions/8533202/list-files-in-local-git-repo
                repo_system_as_list("git ls-tree --full-tree -r HEAD --name-only")
        end
        def find_commit_for_same_component(compound_commit)
                compound_commit.commits.each do | commit |
                        if commit.repo.eql?(self.repo)
                                return commit
                        end
                end
                return nil
        end
        class << self
                def from_hash(h)
                        change_tracker_host_and_port = h.get("change_tracker_host_and_port", "localhost:11111")
                        change_tracker_host, change_tracker_port = change_tracker_host_and_port.split(/:/)
                        change_tracker = Change_tracker.new(change_tracker_host, change_tracker_port)
                        repoName       = h.get("gitRepoName")
                        branch         = h.get("gitBranch")
                        commit_id       = h.get("gitCommitId")
                        Git_commit.new(change_tracker, repoName, branch, commit_id)
                end
                def test()
                        ct = Change_tracker.new()
                        #git_repo_name = "git@orahub.oraclecorp.com:faiza.bounetta/promotion-config.git"
                        git_repo_name = "git;orahub.oraclecorp.com;faiza.bounetta/promotion-config.git;"
                        gc1 = Git_commit.new(ct, git_repo_name, "master", "dc68aa99903505da966358f96c95f946901c664b")
                        gc2 = Git_commit.new(ct, git_repo_name, "master", "42f2d95f008ea14ea3bb4487dba8e3e74ce992a1")
                        gc1_file_list = gc1.list_files
                        gc2_file_list = gc2.list_files
                        U.assert_eq(713, gc1_file_list.size)
                        U.assert_eq(713, gc2_file_list.size)
                        U.assert_eq(".gitignore", gc1_file_list[0])
                        U.assert_eq(".gitignore", gc2_file_list[0])
                        U.assert_eq("version.txt", gc1_file_list[712])
                        U.assert_eq("version.txt", gc2_file_list[712])
                        gc1_added_or_changed_file_list = gc1.list_files_added_or_updated
                        gc2_added_or_changed_file_list = gc2.list_files_added_or_updated
                        U.assert_eq(0, gc1_added_or_changed_file_list.size)
                        U.assert_eq(1, gc2_added_or_changed_file_list.size)
                        U.assert_eq("src/main/java/com/oracle/syseng/configuration/repository/IntegrationRepositoryImpl.java", gc2_added_or_changed_file_list[0])
                        
                        cc1 = Compound_commit.from_json(<<-EOS)
                        {
                        "gitUItoCommit": "https://orahub.oraclecorp.com/faiza.bounetta/promotion-config/commit/dc68aa99903505da966358f96c95f946901c664b",
                        "gitRepoName": "git@orahub.oraclecorp.com:faiza.bounetta/promotion-config.git",
                        "gitBranch": "master",
                        "gitCommitId": "dc68aa99903505da966358f96c95f946901c664b",
                        "dependencies": [] }
                        EOS
                        
                        cc2 = Compound_commit.from_json(<<-EOS)
                        {
                        "gitUItoCommit": "https://orahub.oraclecorp.com/faiza.bounetta/promotion-config/commit/42f2d95f008ea14ea3bb4487dba8e3e74ce992a1",
                        "gitRepoName": "git@orahub.oraclecorp.com:faiza.bounetta/promotion-config.git",
                        "gitBranch": "master",
                        "gitCommitId": "42f2d95f008ea14ea3bb4487dba8e3e74ce992a1",
                        "dependencies": []}
                        EOS
                        
                        U.assert_eq(1, cc1.commits.size)
                        U.assert_eq(1, cc2.commits.size)
                        U.assert_eq(gc1, cc1.commits[0], "cc1 commit")
                        U.assert_eq(gc2, cc2.commits[0], "cc2 commit")
                        U.assert_eq([], cc2.find_commits_for_components_that_were_added_since(cc1), "cc2 added commits")
                        #U.assert_eq([], cc2.find_commits_for_components_that_were_removed_since(cc1), "cc2 removed commits")
                        U.assert_eq([], cc1.find_commits_for_components_that_were_added_since(cc2), "cc1 added commits")
                        #U.assert_eq([], cc1.find_commits_for_components_that_were_removed_since(cc2), "cc1 removed commits")
                        changed_commits1 = cc1.find_commits_for_components_that_changed_since(cc2)
                        changed_commits2 = cc2.find_commits_for_components_that_changed_since(cc1)
                        U.assert_eq(1, changed_commits1.size)
                        U.assert_eq(1, changed_commits2.size)
                        U.assert_eq(gc1, changed_commits1[0])
                        U.assert_eq(gc2, changed_commits2[0])
                end
        end
end

class Compound_commit
        attr_accessor :top_commit
        attr_accessor :dependency_commits
        attr_accessor :json_obj

        def initialize(json_obj, top_commit, dependency_commits)
                self.top_commit = top_commit
                self.dependency_commits = dependency_commits
                self.json_obj = json_obj
        end
        def commits()
                z = []
                z << self.top_commit
                z.concat(self.dependency_commits)
        end
        #def find_commits_for_components_that_were_removed_since(other_compound_commit)
        #        commits_for_components_that_were_removed = []
        #        other_compound_commit.commits.each do | commit |
        #                if !commit.component_contained_by?(self)
        #                        commits_for_components_that_were_removed << commit
        #                end
        #        end
        #        commits_for_components_that_were_removed
        #end
        def find_commits_for_components_that_were_added_since(other_compound_commit)
                commits_for_components_that_were_added = []
                self.commits.each do | commit |
                        if !commit.component_contained_by?(other_compound_commit)
                                commits_for_components_that_were_added << commit
                        end
                end
                commits_for_components_that_were_added
        end
        def find_commits_for_components_that_changed_since(other_compound_commit)
                commits_for_components_that_changed = []
                self.commits.each do | commit |
                        previous_commit_for_same_component = commit.find_commit_for_same_component(other_compound_commit)
                        if previous_commit_for_same_component
                                commits_for_components_that_changed << commit
                        end
                end
                commits_for_components_that_changed
        end
        def list_files_added_or_updated_since(other_compound_commit)
                commits_for_components_that_were_added   = self.find_commits_for_components_that_were_added_since(other_compound_commit)
                commits_which_were_updated               = self.find_commits_for_components_that_changed_since(other_compound_commit)
                
                added_files = []
                commits_for_components_that_were_added.each do | commit |
                        added_files += commit.list_files()
                end
                
                updated_files = []
                commits_which_were_updated.each do | commit |
                        updated_files += commit.list_files_added_or_updated()
                end
                added_files + updated_files
        end
        def to_s()
                "Compound_commit(#{self.json_obj}/#{self.top_commit}/#{self.dependency_commits})"
        end
        def to_json()
                z = "{"
                z << self.top_commit.to_json
                self.dependency_commits.each do | dependency_commit |
                        z << dependency_commit.to_json
                end
                z << "}"
                z
        end
        class << self
                def from_file(json_fn)
                        from_json(IO.read(json_fn))
                end
                def from_url(url_to_json)
                        from_json(Net::HTTP.get_response(URI.parse(url)).body)
                end
                def from_json(json_text)
                        json_obj = Json_obj.new(json_text)
                        top_commit = Git_commit.from_hash(json_obj)
                        dependency_commits = []
                        json_obj.get("dependencies", []).each do | dependency |
                                dependency_commits << Git_commit.from_hash(dependency)
                        end
                        Compound_commit.new(json_obj, top_commit, dependency_commits)
                end
                def from_descriptor(descriptor)
                        # e.g., git;git.osn.oraclecorp.com;osn/cec-server-integration;branch_name;change_tracker_host:change_tracker_port;aaaaaabbbbbcccc
                        source_control_type, source_control_host, repo_name, branch, commit_id, change_tracker_host_and_port = descriptor.split(/;/)
                        case source_control_type
                        when "git"
                                repo = Git_repo.new(repo_name)
                                repo.write_codeline_to_disk(branch, commit_id)
                        else
                                raise "source control type #{source_control_host} not implemented"
                        end
                end
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
                compound_commit1 = Compound_commit.from_file(json_fn1)
                compound_commit2 = Compound_commit.from_file(json_fn2)
                compound_commit2.list_files_added_or_updated_since(compound_commit1).each do | changed_file |
                        puts changed_file
                end
        end
        class << self
        end
end

class Global
        class << self
                attr_accessor :data_json_fn
                attr_accessor :data
                def init_data()
                        if !data
                                if !data_json_fn
                                        data_json_fn = "/etc/change_tracker.json"
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
                        scratch_dir_root = get("scratch_dir", "/scratch/change_tracker.tmp")
                        key = key.gsub(/[^\w]/, "_")
                        scratch_dir = scratch_dir_root + "/" + key
                        FileUtils.mkdir_p(scratch_dir)
                        scratch_dir
                end
                def test()
                        U.assert_eq("test.val", Global.get("test.key"))
                        U.assert_eq("default val", Global.get("test.nonexistent_key", "default val"))
                end
        end
end

class Cec_gradle_parser
	def initialize()
		
	end
	class << self
                def to_compound_commit(gradle_deps_fn)
                        top_commit = Git_commit.new()
                        dependency_commits = []
                        IO.readlines(deps_fn).grep(/^ *manifest\s+"com./).each do | raw_manifest_line |
                                pom_url = Cec_gradle_parser.generate_manifest_url(raw_manifest_line)
                                pom_content = U.rest_get(pom_url)
                                h = XmlSimple.xml_in(pom_content)
                                #pp h
                                puts "-------------------------------------------------"
                                puts h["properties"][0]
                                git_repo_name = h["properties"][0]["git.repo.name"]
                                git_repo_branch = h["properties"][0]["git.repo.branch"]
                                git_repo_commit_id = h["properties"][0]["git.repo.commit.id"]
                                
                                dependency_commits << Git_commit.new(nil, git_repo_name, git_repo_branch, git_repo_commit_id)
                                
                                # jenkins.git-branch # master_external
                                # jenkins.build-url # https://osnci.us.oracle.com/job/infra.social.build.pl.master_external/270/
                                # enkins.build-id # 270
                                
                                
                                puts "-------------------------------------------------"
                                exit
                        end
                        Compound_commit.new(nil, top_commit, dependency_commits)
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
                                #top_package_components = "socialnetwork/cef"
                        else
                                top_package_components = "cecs/#{component}"
                                #top_package_components = "cecs/analytics"
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
                        U.assert_eq(expected_generated_manifest_url, actual_generated_manifest_url)
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


cms = Change_tracker_app.new

j = 0
while ARGV.size > j do
        arg = ARGV[j]
        case arg
        when "-compound_commit_json_of"
                j += 1
                compound_commit = Compound_commit.from_descriptor(ARGV[j])
                print compound_commit.to_json
                exit
        when "-dry"
                U.dry_mode = true
        when "-test"
                U.test_mode = true
                Global.test
                Git_commit.test()
                Cec_gradle_parser.test
                exit
        when "-v"
                U.trace = true
        else
                if !cms.json_fn1
                        cms.json_fn1 = ARGV[j]
                elsif !cms.json_fn2
                        cms.json_fn2 = ARGV[j]
                else
                        raise "did not understand \"#{ARGV[j]}\""
                end
        end
        j += 1
end
cms.go
