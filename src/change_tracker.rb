require_relative 'u'
require 'rubygems'
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
        attr_accessor :name
        attr_accessor :user
        attr_accessor :pw
        attr_accessor :global_data_prefix

        def initialize(name)
                self.name = name
                self.global_data_prefix = "git_repo_#{name}."
                self.user = get("user", "UNUSED")
                self.pw   = get("pw",   "UNUSED")
        end
        def to_s()
                z = "Git_repo(#{name}"
                if self.user != "UNUSED" || self.pw != "UNUSED"
                        z << "(#{self.user}/#{self.pw}"
                end
                z
        end
        def eql?(other)
                self.name.eql?(other.name) && self.user.eql?(other.user) && self.pw.eql?(other.pw)
        end
        def get(key, default_val)
                Global.get(self.global_data_prefix + key, default_val)
        end
        def write_codeline_to_disk(branch, commitId)
                codeline_root_parent = Global.get_scratch_dir(self.name)
                if Dir.entries(codeline_root_parent).size == 2 # only contains ., ..
                        U.system("git clone #{name}", nil, codeline_root_parent)
                end
                dir = U.only_child_of(codeline_root_parent)
                if Dir.entries(dir).size == 2
                        raise "error: expected #{dir} to be populated after cloning"
                end
                dir
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
        attr_accessor :commitId
        def initialize(change_tracker, repoName, branch, commitId)
                self.change_tracker = change_tracker
                self.repo = Git_repo.new(repoName)
                self.branch = branch
                self.commitId = commitId
        end
        def eql?(other)
                other && self.change_tracker.eql?(other.change_tracker) && self.repo.eql?(other.repo) && self.branch.eql?(other.branch) && self.commitId.eql?(other.commitId)
        end
        def to_s()
                "Git_commit(#{self.change_tracker}, #{self.repo}, #{self.branch}, #{self.commitId})"
        end
        def write_codeline_to_disk()
                repo.write_codeline_to_disk(self.branch, self.commitId)
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
                repo_system_as_list("git diff-tree --no-commit-id --name-only -r #{self.commitId}")
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
                        commitId       = h.get("gitCommitId")
                        Git_commit.new(change_tracker, repoName, branch, commitId)
                end
                def test()
                        ct = Change_tracker.new()
                        git_repo_name = "git@orahub.oraclecorp.com:faiza.bounetta/promotion-config.git"
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
        attr_accessor :commits
        attr_accessor :json_obj

        def initialize(json_obj, commits)
                self.commits = commits
                self.json_obj = json_obj
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
                "Compound_commit(#{self.json_obj}/#{self.commits})"
        end
        class << self
                def from_file(json_fn)
                        from_json(IO.read(json_fn))
                end
                def from_url(url_to_json)
                        from_json(Net::HTTP.get_response(URI.parse(url)).body)
                end
                def from_json(json_text)
                        commits = []

                        json_obj = Json_obj.new(json_text)
                        commits << Git_commit.from_hash(json_obj)
                        json_obj.get("dependencies", []).each do | dependency |
                                commits << Git_commit.from_hash(dependency)
                        end
                        Compound_commit.new(json_obj, commits)
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
        end
end

cms = Change_tracker_app.new

j = 0
while ARGV.size > j do
        arg = ARGV[j]
        case arg
        when "-dry"
                U.dry_mode = true
        when "-test"
                U.test_mode = true
                Git_commit.test()
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
