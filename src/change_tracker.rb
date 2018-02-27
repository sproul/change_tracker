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

class Json_obj
        attr_accessor :h
        def initialize(json_text = nil)
                if json_text
                        self.h = JSON.parse(json_text)
                else
                        self.h = Hash.new
                end
        end
        def array_of_json_to_s(a, multi_line_mode = false)
                z = nil
                a.each do | elt |
                        if !z
                                z = "["
                        else
                                z << ","
                        end
                        z << "\n" if multi_line_mode
                        z << elt.json
                end
                z << "\n" if multi_line_mode
                z << "]"
                z
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
        def has_key?(key)
                h.has_key?(key)
        end
        class << self
                def format_pair(key, val)
                        z = "\"#{key}\" : "
                        if val.class.method_defined? :to_json
                                z << val.to_json
                        end
                        z
                end
        end
end

class Git_repo
        DEFAULT_BRANCH = "master"

        attr_accessor :project_name
        attr_accessor :global_data_prefix
        attr_accessor :branch_name
        attr_accessor :source_control_server
        attr_accessor :source_control_type
        attr_accessor :change_tracker_host_and_port

        def initialize(repo_spec, change_tracker_host_and_port = nil)
                self.change_tracker_host_and_port = change_tracker_host_and_port
                source_control_type, source_control_server, project_name, branch_name = repo_spec.split(/;/)
                if source_control_type != "git"
                        raise "unexpected source_control_type #{source_control_type} from #{repo_spec}"
                end
                self.source_control_type = source_control_type
                if !branch_name || branch_name == ""
                        self.branch_name = DEFAULT_BRANCH
                else
                        self.branch_name = branch_name
                end
                raise "empty project name" unless project_name && (project_name != "")
                self.project_name = project_name
                self.global_data_prefix = "git_repo_#{project_name}."
                self.source_control_server = source_control_server
                if !Git_repo.codeline_root_parent
                        Git_repo.codeline_root_parent = Global.get_scratch_dir("git")
                end
        end
        def latest_commit_id()
                self.system("git log --pretty=format:'%H' -n 1")
        end
        def spec()
                Git_repo.make_spec(source_control_server, project_name, branch_name, change_tracker_host_and_port)
        end
        def to_s()
                spec
        end
        def eql?(other)
                self.project_name.eql?(other.project_name) &&
                self.change_tracker_host_and_port.eql?(other.change_tracker_host_and_port) &&
                self.branch_name.eql?(other.branch_name)
        end
        def get(key, default_val=nil)
                Global.get(self.global_data_prefix + key, default_val)
        end
        def get_project_name_prefix()
                project_name.sub(/\/.*/, '')
        end
        def get_file(path)
                fn = "#{self.codeline_disk_root}/#{path}"
                if !File.exist?(fn)
                        raise "could not read #{fn}"
                end
                IO.read(fn)
        end
        def get_credentials()
                username, pw = Global.get_credentials("#{source_control_server}/#{project_name}", true)
                if !username
                        username, pw = Global.get_credentials(source_control_server, true)
                end
                return username, pw
        end
        def codeline_disk_exist?()
                root_dir = codeline_disk_root()
                # puts "exist? checking #{root_dir}"
                # if dir is empty, then there are 2 entries (., ..):
                return Dir.exist?(root_dir) && (Dir.entries(root_dir).size > 2)
        end
        def codeline_disk_root()
                "#{Git_repo.codeline_root_parent}/#{self.source_control_server}/#{project_name}"
        end
        def codeline_disk_remove()
                root_dir = codeline_disk_root()
                FileUtils.rm_rf(root_dir)
        end
        def codeline_disk_write(commit_id = nil)
                root_dir = codeline_disk_root()
                if !codeline_disk_exist?
                        root_parent = File.dirname(root_dir)       # leave it to 'git clone' to make the root_dir itself
                        FileUtils.mkdir_p(root_parent)

                        username, pw = self.get_credentials
                        if !username
                                git_arg = "git@#{self.source_control_server}:#{project_name}.git"
                        else
                                username_pw = "#{username}"
                                if pw != ""
                                        username_pw << ":#{pw}"
                                end
                                git_arg = "https://#{username_pw}@#{self.source_control_server}/#{project_name}.git"
                        end
                        if branch_name && branch_name != DEFAULT_BRANCH
                                branch_arg = "-b \"#{branch_name}\""
                        else
                                branch_arg = ""
                        end
                        # from Steve mail -- not sure if I've accounted for everything already...
                        # git clone ...
                        # git checkout master
                        # git pull      # may not be necessary
                        # 
                        U.system("git clone #{branch_arg} \"#{git_arg}\"", nil, root_parent)
                end
                if !codeline_disk_exist?
                        raise "error: #{self} does not exist on disk after supposed clone"
                end
                root_dir
        end
        def system_as_list(cmd)
                local_codeline_root_dir = self.codeline_disk_write
                #puts "cd #{local_codeline_root_dir}; #{cmd}"
                raise "no codeline for #{self}" unless local_codeline_root_dir
                U.system_as_list(cmd, nil, local_codeline_root_dir)
        end
        def system(cmd)
                local_codeline_root_dir = self.codeline_disk_write
                raise "no codeline for #{self}" unless local_codeline_root_dir
                U.system(cmd, nil, local_codeline_root_dir)
        end
        class << self
                attr_accessor :codeline_root_parent
                def make_spec(source_control_server, repo_name, branch=DEFAULT_BRANCH, change_tracker_host_and_port=nil)
                        source_control_type = "git"
                        raise "bad source_control_server #{source_control_server}" unless source_control_server && source_control_server.is_a?(String) && source_control_server != ""
                        raise "bad repo_name #{repo_name}" unless repo_name && repo_name.is_a?(String) && repo_name != ""
                        branch = "" unless branch
                        change_tracker_host_and_port = "" unless change_tracker_host_and_port
                        "#{source_control_type};#{source_control_server};#{repo_name};#{branch};#{change_tracker_host_and_port}"
                end
                def test_clean()
                        gr = Git_repo.new(TEST_REPO_NAME)
                        gr.codeline_disk_remove
                        U.assert(!gr.codeline_disk_exist?)
                end
                def test()
                        gr = Git_repo.new("git;git.osn.oraclecorp.com;osn/cec-server-integration;;")
                        gr.codeline_disk_write
                        U.assert(gr.codeline_disk_exist?)
                        deps_gradle_content = gr.get_file("deps.gradle")
                        U.assert(deps_gradle_content)
                        U.assert(deps_gradle_content != "")
                        manifest_lines = deps_gradle_content.split("\n").grep(/manifest/)
                        U.assert(manifest_lines.size > 1)
                        #
                        # I think maybe we don't need json support for this obj
                        #json = gr.to_json
                        #gr2 = Git_repo.from_json(json)
                        #U.assert_eq(gr, gr2, "json copy")
                end
        end
end

class Git_commit
        attr_accessor :repo
        attr_accessor :commit_id
        attr_accessor :comment  # only set if this object populated by a call to git log
        def initialize(repo_expr, commit_id, comment=nil)
                if repo_expr.is_a? String
                        repo_spec = repo_expr
                        self.repo = Git_repo.new(repo_spec)
                elsif repo_expr.is_a? Git_repo
                        self.repo = repo_expr
                else
                        raise "unexpected repo type #{repo.class}"
                end
                self.commit_id = commit_id
                self.comment = comment
        end
        def list_changes_since(other_compound_commit)
                change_lines = repo.system_as_list("git log --pretty=format:'%H %s' #{other_compound_commit.commit_id}..#{commit_id}")

                change_lines.map.each do | change_line |
                        raise "did not understand #{change_line}" unless change_line =~ /^([0-9a-f]+) (.*)/
                        change_id, comment = $1, $2
                        Git_commit.from_spec("#{repo.spec};#{change_id}", comment)
                end
        end
        def list_changed_files()
                [ self.repo.spec, repo.system_as_list("git diff-tree --no-commit-id --name-only -r #{self.commit_id}") ]
        end
        def list_files_changed_since(other_compound_commit)
                changes = list_changes_since(other_compound_commit)
                files_changed_with_duplicates = changes.inject([]){|files_changed, commit| files_changed + commit.list_changed_files}
                return files_changed_with_duplicates.uniq
        end
        def eql?(other)
                other && self.repo.eql?(other.repo) && self.commit_id.eql?(other.commit_id)
        end
        def to_s()
                z = "Git_commit(#{self.repo.spec}, #{self.commit_id}"
                if self.comment
                        z << ", !!!#{comment}!!!"
                end
                z << ")"
                z
        end
        def to_s_with_comment()
                raise "comment not set" unless comment
                to_s
        end
        def to_json()
                h = Hash.new
                h["repo_spec"] = repo.to_s
                h["commit_id"] = commit_id
                if comment
                        h["comment"] = comment
                end
                JSON.generate(h)
        end
        def codeline_disk_write()
                repo.codeline_disk_write(self.commit_id)
        end
        def component_contained_by?(compound_commit)
                self.find_commit_for_same_component(compound_commit) != nil
        end
        def list_files_added_or_updated()
                # https://stackoverflow.com/questions/424071/how-to-list-all-the-files-in-a-commit
                repo.system_as_list("git diff-tree --no-commit-id --name-only -r #{self.commit_id}")
        end
        def list_files()
                # https://stackoverflow.com/questions/8533202/list-files-in-local-git-repo
                repo.system_as_list("git ls-tree --full-tree -r HEAD --name-only")
        end
        def list_bug_IDs_since(other_commit)
                changes = list_changes_since(other_commit)
                bug_IDs = Git_commit.grep_group1(changes, Compound_commit.bug_id_regexp)
                bug_IDs
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
                TEST_SOURCE_SERVER_AND_PROJECT_NAME = "orahub.oraclecorp.com;faiza.bounetta/promotion-config"
                TEST_REPO_SPEC = "git;#{TEST_SOURCE_SERVER_AND_PROJECT_NAME};"

                def list_changes_between(commit_spec1, commit_spec2)
                        commit1 = Git_commit.from_spec(commit_spec1)
                        commit2 = Git_commit.from_spec(commit_spec2)
                        return commit2.list_changes_since(commit1)
                end
                def from_hash(h)
                        if h.has_key?("gitRepoName")
                                # puts "fh: #{h}"
                                # fh: Json_obj({"gitUItoCommit"=>"https://orahub.oraclecorp.com/faiza.bounetta/promotion-config/commit/dc68aa99903505da966358f96c95f946901c664b", "gitRepoName"=>"orahub.oraclecorp.com;faiza.bounetta/promotion-config", "gitBranch"=>"master", "gitCommitId"=>"dc68aa99903505da966358f96c95f946901c664b", "dependencies"=>[]})
                                change_tracker_host_and_port = h.get("change_tracker_host_and_port", "")
                                source_control_server_and_repo_name = h.get("gitRepoName")
                                branch         = h.get("gitBranch")
                                commit_id      = h.get("gitCommitId")
                                source_control_server, repo_name = source_control_server_and_repo_name.split(/;/)
                                repo_spec = Git_repo.make_spec(source_control_server, repo_name, branch, change_tracker_host_and_port)
                        else
                                repo_spec = h.get("repo_spec")
                                commit_id = h.get("commit_id")
                        end
                        Git_commit.new(repo_spec, commit_id)
                end
                def from_json(json_text)
                        json_obj = Json_obj.new(json_text)
                        # puts "gc from_json: #{json_text}"
                        # gc fromjson: {"repo_spec" : "git;git.osn.oraclecorp.com;osn/cec-server-integration;master;","commit_id" : "2bc0b1a58a9277e97037797efb93a2a94c9b6d99"}
                        repo_spec = json_obj.get("repo_spec")
                        commit_id = json_obj.get("commit_id")
                        Git_commit.new(repo_spec, commit_id)
                end
                def from_spec(repo_spec_and_commit_id, comment=nil)
                        if repo_spec_and_commit_id !~ /(.*);([^;]*)$/
                                raise "could not parse #{repo_spec_and_commit_id}"
                        end
                        repo_spec, commit_id = $1, $2;
                        gr = Git_repo.new(repo_spec)
                        if commit_id == ""
                                commit_id = gr.latest_commit_id
                        end
                        Git_commit.new(gr, commit_id, comment)
                end
                def grep_group1(commits, regexp)
                        raise "no regexp" unless regexp
                        group1_hits = []
                        commits.each do | commit |
                                raise "comment not set for #{commit}" unless commit.comment
                                if regexp.match(commit.comment)
                                        raise "no group 1 match for #{regexp}" unless $1
                                        group1_hits << $1
                                end
                        end
                        group1_hits
                end
                def list_files_changed_between(commit_spec1, commit_spec2)
                        commit1 = Git_commit.from_spec(commit_spec1)
                        commit2 = Git_commit.from_spec(commit_spec2)
                        return commit2.list_files_changed_since(commit1)
                end
                def test_list_changes_since()
                        compound_spec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64"
                        compound_spec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                        gc1 = Git_commit.from_spec(compound_spec1)
                        gc2 = Git_commit.from_spec(compound_spec2)
                        changes = gc2.list_changes_since(gc1)
                        changes2 = Git_commit.list_changes_between(compound_spec1, compound_spec2)
                        U.assert_eq(changes, changes2, "Git_commit.test_list_changes_since - vfy same result from wrapper 0")

                        g1b = Git_commit.from_spec("git;git.osn.oraclecorp.com;osn/cec-server-integration;master;;22ab587dd9741430c408df1f40dbacd56c657c3f")
                        g1a = Git_commit.from_spec("git;git.osn.oraclecorp.com;osn/cec-server-integration;master;;7dfff5f400b3011ae2c4aafac286d408bce11504")

                        U.assert_eq([gc2, g1b, g1a], changes)
                end
                def test_list_files_changed_since()
                        compound_spec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64"
                        compound_spec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                        gc1 = Git_commit.from_spec(compound_spec1)
                        gc2 = Git_commit.from_spec(compound_spec2)
                        
                        changed_files = gc2.list_files_changed_since(gc1)
                        changed_files2 = Git_commit.list_files_changed_between(compound_spec1, compound_spec2)
                        U.assert_eq(changed_files, changed_files2, "vfy same result from wrapper 1")
                        U.assert_eq(["git;git.osn.oraclecorp.com;osn/cec-server-integration;master;", ["component.properties", "deps.gradle"]], changed_files, "Git_commit.test_list_files_changed_since")
                end
                def test_json()
                        repo_spec = "git;git.osn.oraclecorp.com;osn/cec-server-integration;master;;2bc0b1a58a9277e97037797efb93a2a94c9b6d99"
                        valentine_commit_id = "2bc0b1a58a9277e97037797efb93a2a94c9b6d99"
                        gc = Git_commit.new(repo_spec, valentine_commit_id)
                        json = gc.to_json
                        U.assert_eq('{"repo_spec":"git;git.osn.oraclecorp.com;osn/cec-server-integration;master;","commit_id":"2bc0b1a58a9277e97037797efb93a2a94c9b6d99"}', json)
                        gc2 = Git_commit.from_json(json)
                        U.assert_eq(gc, gc2, "test ability to export to json, then import from that json back to the same object")
                end
                def test_list_bug_IDs_since()
                        # I noticed that for the commits in this range, there is a recurring automated comment "caas.build.pl.master/3013/" -- so
                        # I thought I would reset the pattern to treat that number like a bug ID for the purposes of the test.
                        # (At some point, i'll need to go find a comment that really does refer to a bug ID.)
                        saved_bug_id_regexp = Compound_commit.bug_id_regexp_val
                        begin
                                compound_spec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64"
                                compound_spec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                                gc1 = Git_commit.from_spec(compound_spec1)
                                gc2 = Git_commit.from_spec(compound_spec2)
                                Compound_commit.bug_id_regexp_val = Regexp.new(".*caas.build.pl.master/(\\d+)/.*", "m")
                                bug_IDs = gc2.list_bug_IDs_since(gc1)
                                U.assert_eq(["3013", "3012", "3011"], bug_IDs, "bug_IDs_since")
                                
                                bug_IDs2 = Compound_commit.list_bug_IDs_between(compound_spec1, compound_spec2)
                                U.assert_eq(bug_IDs, bug_IDs2, "verify same result  from list_bug_IDs_between wrapper")
                        ensure
                                Compound_commit.bug_id_regexp_val = saved_bug_id_regexp
                        end
                end
                def test()
                        gc1 = Git_commit.new(TEST_REPO_SPEC, "dc68aa99903505da966358f96c95f946901c664b")
                        gc2 = Git_commit.new(TEST_REPO_SPEC, "42f2d95f008ea14ea3bb4487dba8e3e74ce992a1")
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
                        "top_commit_repo": "#{TEST_REPO_SPEC}",
                        "top_commit_id": "dc68aa99903505da966358f96c95f946901c664b",
                        "deps": [] }
                        EOS

                        cc2 = Compound_commit.from_json(<<-EOS)
                        {
                        "gitUItoCommit": "https://orahub.oraclecorp.com/faiza.bounetta/promotion-config/commit/42f2d95f008ea14ea3bb4487dba8e3e74ce992a1",
                        "top_commit_repo": "#{TEST_REPO_SPEC}",
                        "top_commit_id": "42f2d95f008ea14ea3bb4487dba8e3e74ce992a1",
                        "deps": []}
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
                        test_json
                        test_list_changes_since()
                        test_list_bug_IDs_since()
                        test_list_files_changed_since()
                end
        end
end

class Compound_commit
        attr_accessor :top_commit
        attr_accessor :dependency_commits

        def initialize(top_commit, dependency_commits)
                if top_commit.is_a?(String)
                        self.top_commit = Git_commit.from_spec(top_commit)
                else
                        self.top_commit = top_commit
                end
                self.dependency_commits = dependency_commits
        end
        def eql?(other)
                self.top_commit.eql?(other.top_commit) && dependency_commits.eql?(other.dependency_commits)
        end
        def to_json()
                h = Hash.new
                h["top_commit_repo"] = top_commit.repo.spec
                h["top_commit_id"] = top_commit.commit_id
                dependency_commits_hash_array = []
                h["deps"] = dependency_commits_hash_array
                dependency_commits.each do | commit |
                        commit_h = Hash.new
                        commit_h["repo_spec"] = commit.repo.spec
                        commit_h["commit_id"] = commit.commit_id
                        dependency_commits_hash_array << commit_h
                end
                JSON.generate(h)
        end
        def commits()
                z = []
                z << self.top_commit
                z = z.concat(self.dependency_commits)
                #puts "z=#{z}"
                z
        end
        def list_files_changed_since(other_compound_commit)
                changes = list_changes_since(other_compound_commit)
                files_changed_with_duplicates = changes.inject([]){|files_changed, commit| files_changed + commit.list_changed_files}
                return files_changed_with_duplicates.uniq
        end
        def list_changes_since(other_compound_commit)
                pairs = get_pairs_of_commits_with_matching_repo(other_compound_commit)
                changes = []
                pairs.each do | pair |
                        commit0 = pair[0]
                        commit1 = pair[1]
                        changes += commit1.list_changes_since(commit0)
                end
                changes
        end
        def get_pairs_of_commits_with_matching_repo(other_compound_commit)
                pairs = []
                self.commits.each do | commit |
                        previous_commit_for_same_component = commit.find_commit_for_same_component(other_compound_commit)
                        if previous_commit_for_same_component
                                pairs << [ previous_commit_for_same_component, commit ]
                        end
                end
                pairs
        end
        def list_bug_IDs_since(other_compound_commit)
                changes = list_changes_since(other_compound_commit)
                bug_IDs = Git_commit.grep_group1(changes, Compound_commit.bug_id_regexp)
                bug_IDs
        end
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
                z = "Compound_commit(#{self.top_commit}/["
                self.dependency_commits.each do | commit |
                        z << " " << commit.to_s
                end
                z << "]"
                z
        end
        class << self
                attr_accessor :bug_id_regexp_val
                def list_bug_IDs_between(compound_commit_spec1, compound_commit_spec2)
                        compound_commit1 = Compound_commit.from_spec(compound_commit_spec1)
                        compound_commit2 = Compound_commit.from_spec(compound_commit_spec2)
                        return compound_commit2.list_bug_IDs_since(compound_commit1)
                end
                def list_changes_between(compound_commit_spec1, compound_commit_spec2)
                        compound_commit1 = Compound_commit.from_spec(compound_commit_spec1)
                        compound_commit2 = Compound_commit.from_spec(compound_commit_spec2)
                        return compound_commit2.list_changes_since(compound_commit1)
                end
                def list_files_changed_between(compound_commit_spec1, compound_commit_spec2)
                        compound_commit1 = Compound_commit.from_spec(compound_commit_spec1)
                        compound_commit2 = Compound_commit.from_spec(compound_commit_spec2)
                        return compound_commit2.list_files_changed_since(compound_commit1)
                end
                def list_last_changes(repo_spec, n)
                        gr = Git_repo.new(repo_spec)
                        # Example log entry:
                        # 
                        # "commit 22ab587dd9741430c408df1f40dbacd56c657c3f"
                        # "Author: osnbt on socialdev Jenkins <ade-generic-osnbt_ww@oracle.com>"
                        # "Date:   Tue Feb 20 09:28:24 2018 -0800"
                        # ""
                        # "    New version com.oracle.cecs.caas:manifest:1.0.3012, initiated by https://osnci.us.oracle.com/job/caas.build.pl.master/3012/"
                        # "    and updated (consumed) by https://osnci.us.oracle.com/job/serverintegration.deptrigger.pl.master/484/"
                        # "    "
                        # "    The deps.gradle file, component.properties and any other @autoupdate files listed in deps.gradle"
                        # "    have been automatically updated to consume these dynamic dependencies."
                        commit_log_entries = gr.system_as_list("git log --oneline -n #{n} --pretty=format:'%H:%s'")
                        commits = []
                        commit_log_entries.each do | commit_log_entry |
                                if commit_log_entry !~ /^([a-f0-9]+):(.*)/m
                                        raise "could not understand #{commit_log_entry}"
                                else
                                        commit_id, comment = $1, $2
                                        commit = Git_commit.new(gr, commit_id)
                                        commit.comment = comment
                                        commits << commit
                                end
                        end
                        commits
                end
                def bug_id_regexp()
                        if !Compound_commit.bug_id_regexp_val
                                z = Global.get("bug_id_regexp_val", ".*Bug (.*).*")
                                Compound_commit.bug_id_regexp_val = Regexp.new(z, "m")
                        end
                        Compound_commit.bug_id_regexp_val
                end
                def from_file(json_fn)
                        from_json(IO.read(json_fn))
                end
                def from_json(json_text)
                        h = JSON.parse(json_text)
                        # fj: {"gitUItoCommit"=>"https://orahub.oraclecorp.com/faiza.bounetta/promotion-config/commit/dc68aa99903505da966358f96c95f946901c664b", "top_commit_repo"=>"git;orahub.oraclecorp.com;faiza.bounetta/promotion-config;", "top_commit_id"=>"dc68aa99903505da966358f96c95f946901c664b", "deps"=>[]}
                        # puts "fj: #{h}"

                        top_commit_repo_spec = h["top_commit_repo"]
                        raise "no top_commit_repo in #{h}" unless top_commit_repo_spec

                        top_commit_id = h["top_commit_id"]
                        raise "no top_commit_id in #{h}" unless top_commit_id

                        top_commit = Git_commit.new(top_commit_repo_spec, top_commit_id)

                        dependency_commits_hash_array = h["deps"]
                        raise "no deps array in #{h}" unless dependency_commits_hash_array

                        dependency_commits = []
                        dependency_commits_hash_array.each do | dependency_h |
                                repo_spec = dependency_h["repo_spec"]
                                commit_id = dependency_h["commit_id"]
                                raise "no repo_spec in #{dependency_h}" unless repo_spec
                                raise "no commit_id in #{dependency_h}" unless commit_id
                                dependency_commits << Git_commit.new(repo_spec, commit_id)
                        end
                        Compound_commit.new(top_commit, dependency_commits)
                end
                #def from_descriptor(repo_spec)
                #        # i.e., git;git.osn.oraclecorp.com;osn/cec-server-integration;branch_name;change_tracker_host:change_tracker_port;aaaaaabbbbbcccc
                #        # e.g., git;git.osn.oraclecorp.com;osn/cec-server-integration;;;2bc0b1a58a9277e97037797efb93a2a94c9b6d99
                #        source_control_type, source_control_server, repo_name, branch, change_tracker_host_and_port, commit_id = repo_spec.split(/;/)
                #        case source_control_type
                #        when "git"
                #                repo_spec = Git_repo.make_spec(source_control_server, repo_name, branch, change_tracker_host_and_port)
                #                repo = Git_repo.new(repo_spec, change_tracker_host_and_port)
                #                repo.codeline_disk_write(commit_id)
                #        else
                #                raise "source control type #{source_control_server} not implemented"
                #        end
                #end
                def from_spec(repo_spec_and_commit_id, dependency_commits=nil)
                        top_commit = Git_commit.from_spec(repo_spec_and_commit_id)
                        if !dependency_commits
                                begin
                                        gr = top_commit.repo
                                        gr.codeline_disk_write
                                        deps_gradle_content = gr.get_file("deps.gradle")
                                        #puts "xxxx: #{deps_gradle_content}"
                                        dependency_commits = Cec_gradle_parser.to_dep_commits(deps_gradle_content, gr)
                                rescue Object => emsg_obj
                                        raise "autodiscover of dependencies failed trying to understand deps.gradle: #{emsg_obj.to_s}"
                                end
                        end
                        Compound_commit.new(top_commit, dependency_commits)
                end
                def from_url(url_to_json)
                        from_json(Net::HTTP.get_response(URI.parse(url)).body)
                end
                def test_list_changes_since()
                        compound_spec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64"
                        compound_spec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                        cc1 = Compound_commit.from_spec(compound_spec1)
                        cc2 = Compound_commit.from_spec(compound_spec2)
                        
                        gc2 = Git_commit.from_spec(compound_spec2)

                        changes = cc2.list_changes_since(cc1)
                        changes2 = Compound_commit.list_changes_between(compound_spec1, compound_spec2)
                        U.assert_eq(changes, changes2, "vfy same result from wrapper 2a")

                        g1b = Git_commit.from_spec("git;git.osn.oraclecorp.com;osn/cec-server-integration;master;;22ab587dd9741430c408df1f40dbacd56c657c3f")
                        g1a = Git_commit.from_spec("git;git.osn.oraclecorp.com;osn/cec-server-integration;master;;7dfff5f400b3011ae2c4aafac286d408bce11504")

                        U.assert_eq([gc2, g1b, g1a], changes)
                end
                def test_list_files_changed_since()
                        compound_spec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64"
                        compound_spec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                        cc1 = Compound_commit.from_spec(compound_spec1)
                        cc2 = Compound_commit.from_spec(compound_spec2)
                        
                        changed_files = cc2.list_files_changed_since(cc1)
                        changed_files2 = Compound_commit.list_files_changed_between(compound_spec1, compound_spec2)
                        U.assert_eq(changed_files, changed_files2, "vfy same result from wrapper 2b")
                        U.assert_eq(["git;git.osn.oraclecorp.com;osn/cec-server-integration;master;", ["component.properties", "deps.gradle"]], changed_files)
                end
                def test_list_bug_IDs_since()
                        # I noticed that for the commits in this range, there is a recurring automated comment "caas.build.pl.master/3013/" -- so
                        # I thought I would reset the pattern to treat that number like a bug ID for the purposes of the test.
                        # (At some point, i'll need to go find a comment that really does refer to a bug ID.)
                        saved_bug_id_regexp = Compound_commit.bug_id_regexp_val
                        begin
                                compound_spec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64"
                                compound_spec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                                gc1 = Compound_commit.from_spec(compound_spec1)
                                gc2 = Compound_commit.from_spec(compound_spec2)
                                Compound_commit.bug_id_regexp_val = Regexp.new(".*caas.build.pl.master/(\\d+)/.*", "m")
                                bug_IDs = gc2.list_bug_IDs_since(gc1)
                                U.assert_eq(["3013", "3012", "3011"], bug_IDs, "bug_IDs_since")
                        ensure
                                Compound_commit.bug_id_regexp_val = saved_bug_id_regexp
                        end
                end
                def test_json_export()
                        json = Compound_commit.from_spec("git;git.osn.oraclecorp.com;osn/cec-server-integration;master;;2bc0b1a58a9277e97037797efb93a2a94c9b6d99").to_json
                        U.assert_eq(%Q[{"top_commit_repo":"git;git.osn.oraclecorp.com;osn/cec-server-integration;master;","top_commit_id":"2bc0b1a58a9277e97037797efb93a2a94c9b6d99","deps":[{"repo_spec":"git;git.osn.oraclecorp.com;ccs/caas;master;","commit_id":"a1466659536cf2225eadf56f43972a25e9ee1bed"},{"repo_spec":"git;git.osn.oraclecorp.com;osn/cef;master;","commit_id":"749581bac1d93cda036d33fbbdbe95f7bd0987bf"}]}], json, "Compound_commit.test_json_export")
                end
                def test()
                        repo_spec = "git;git.osn.oraclecorp.com;osn/cec-server-integration;master;;2bc0b1a58a9277e97037797efb93a2a94c9b6d99"
                        valentine_commit_id = "2bc0b1a58a9277e97037797efb93a2a94c9b6d99"
                        cc = Compound_commit.from_spec("#{repo_spec};#{valentine_commit_id}")
                        U.assert(cc.dependency_commits.size > 0, "cc.dependency_commits.size > 0")
                        json = cc.to_json
                        U.assert_eq('{"top_commit_repo":"git;git.osn.oraclecorp.com;osn/cec-server-integration;master;","top_commit_id":"2bc0b1a58a9277e97037797efb93a2a94c9b6d99","deps":[{"repo_spec":"git;git.osn.oraclecorp.com;ccs/caas;master;","commit_id":"a1466659536cf2225eadf56f43972a25e9ee1bed"},{"repo_spec":"git;git.osn.oraclecorp.com;osn/cef;master;","commit_id":"749581bac1d93cda036d33fbbdbe95f7bd0987bf"}]}', json, "dependency_gather1")
                        cc2 = Compound_commit.from_json(json)
                        U.assert_eq(cc, cc2, "json copy dependency_gather1")

                        cc_latest = Compound_commit.from_spec("git;git.osn.oraclecorp.com;osn/cec-server-integration;;;")
                        U.assert(cc_latest && cc_latest != "")
                        cc9 = Compound_commit.from_spec("git;git.osn.oraclecorp.com;osn/cec-server-integration;;;2bc0b1a58a9277e97037797efb93a2a94c9b6d99")
                        U.assert_eq('{"top_commit_repo":"git;git.osn.oraclecorp.com;osn/cec-server-integration;master;","top_commit_id":"2bc0b1a58a9277e97037797efb93a2a94c9b6d99","deps":[{"repo_spec":"git;git.osn.oraclecorp.com;ccs/caas;master;","commit_id":"a1466659536cf2225eadf56f43972a25e9ee1bed"},{"repo_spec":"git;git.osn.oraclecorp.com;osn/cef;master;","commit_id":"749581bac1d93cda036d33fbbdbe95f7bd0987bf"}]}', cc9.to_json)
                        test_list_changes_since()
                        test_list_bug_IDs_since()
                        test_list_files_changed_since()
                        test_json_export()
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
                        U.assert_eq("test.val", Global.get("test.key"))
                        U.assert_eq("default val", Global.get("test.nonexistent_key", "default val"))
                        username, pw = Global.get_credentials("test_server")
                        U.assert_eq("some_username", username)
                        U.assert_eq("some_pw",       pw)
                end
        end
end

class Cec_gradle_parser
        def initialize()

        end
        class << self
                def to_dep_commits(gradle_deps_text, gr)
                        dependency_commits = []
                        gradle_deps_text.split(/\n/).grep(/^\s*manifest\s+"com./).each do | raw_manifest_line |

                                # raw_manifest_line=  manifest "com.oracle.cecs.caas:manifest:1.master_external.528"         //@trigger
                                #puts "raw_manifest_line=#{raw_manifest_line}"

                                pom_url = Cec_gradle_parser.generate_manifest_url(raw_manifest_line)
                                pom_content = U.rest_get(pom_url)
                                h = XmlSimple.xml_in(pom_content)
                                # {"git.repo.name"=>["caas.git"], "git.repo.branch"=>["master_external"], "git.repo.commit.id"=>["90f08f6882382e0134191ca2a993191c2a2f5b48"], "git.commit-id"=>["caas.git:90f08f6882382e0134191ca2a993191c2a2f5b48"], "jenkins.git-branch"=>["master_external"], "jenkins.build-url"=>["https://osnci.us.oracle.com/job/caas.build.pl.master_external/528/"], "jenkins.build-id"=>["2018-02-16_21:51:53"]}
                                # puts h["properties"][0]

                                git_project_basename = h["properties"][0]["git.repo.name"][0] # e.g., caas.git
                                git_repo_branch = h["properties"][0]["git.repo.branch"][0]
                                git_repo_commit_id = h["properties"][0]["git.repo.commit.id"][0]

                                if git_project_basename == "caas.git"
                                        repo_name = "ccs/#{git_project_basename}"
                                else
                                        repo_name = "#{gr.get_project_name_prefix}/#{git_project_basename}"
                                end
                                repo_name.sub!(/.git$/, '')
                                
                                repo_spec = Git_repo.make_spec(gr.source_control_server, repo_name, git_repo_branch)
                                dependency_commits << Git_commit.new(repo_spec, git_repo_commit_id)

                                # jenkins.git-branch # master_external
                                # jenkins.build-url # https://osnci.us.oracle.com/job/infra.social.build.pl.master_external/270/
                                # jenkins.build-id # 270
                        end
                        if dependency_commits.empty?
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
                        puts "EOT"
                end
        end
end
