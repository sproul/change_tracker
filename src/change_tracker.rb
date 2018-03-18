require_relative 'u'
require_relative 'error_holder'
require_relative 'file_set'
require_relative 'json_obj'
require_relative 'source_control_repo'
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

class Cspec < Error_holder
        AUTODISCOVER = "+"              #       autodiscover_dependencies_by_looking_in_codeline
        AUTODISCOVER_REGEX = /\+$/      #       regex to find AUTODISCOVER appended to a repo_and_commit_id
        attr_accessor :repo
        attr_accessor :commit_id
        attr_accessor :comment  # only set if this object populated by a call to git log
        def initialize(repo_expr, commit_id, comment=nil)
                if repo_expr.is_a? String
                        repo_spec = repo_expr
                        self.repo = Repo.new(repo_spec)
                elsif repo_expr.is_a? Repo
                        self.repo = repo_expr
                else
                        self.raise "unexpected repo type #{repo.class}"
                end
                self.commit_id = commit_id
                self.comment = comment
                puts "Cspec.new(#{self.repo_and_commit_id})" if Cec_gradle_parser.trace_autodiscovery
        end
        def unreliable_autodiscovery_of_dependencies_from_build_configuration()
                if !Cspec.autodiscovered_deps
                        Cspec.autodiscovered_deps = Hash.new
                elsif Cspec.autodiscovered_deps.has_key?(self.repo_and_commit_id)
                        return Cspec.autodiscovered_deps[self.repo_and_commit_id]
                end
                self.repo.codeline_disk_write
                deps_gradle_content = self.repo.get_file("deps.gradle", self.commit_id)
                if deps_gradle_content
                        dependency_commits = Cec_gradle_parser.to_dep_commits(deps_gradle_content, self.repo)
                else
                        dependency_commits = []
                end
                puts "unreliable_autodiscovery_of_dependencies_from_build_configuration returns #{dependency_commits}" if Cec_gradle_parser.trace_autodiscovery
                Cspec.autodiscovered_deps[self.repo_and_commit_id] = dependency_commits
                dependency_commits
        end
        def list_changes_since(other_commit)
                change_lines = repo.system_as_list("git log --pretty=format:'%H %s' #{other_commit.commit_id}..#{commit_id}")
                commits = []
                change_lines.map.each do | change_line |
                        self.raise "did not understand #{change_line}" unless change_line =~ /^([0-9a-f]+) (.*)$/
                        change_id, comment = $1, $2
                        commits << Cspec.from_repo_and_commit_id("#{repo.spec};#{change_id}", comment)
                end
                commits
        end
        def list_changed_files()
                File_set.new(self.repo, repo.system_as_list("git diff-tree --no-commit-id --name-only -r #{self.commit_id}"))
        end
        def list_files_changed_since(other_commit)
                commits = list_changes_since(other_commit)
                fss = File_sets.new
                commits.each do | commit |
                        fss.add_set(commit.list_changed_files)
                end
                return fss
        end
        def eql?(other)
                other && self.repo.eql?(other.repo) && self.commit_id.eql?(other.commit_id)
        end
        def to_s()
                z = "Cspec(#{self.repo.spec}, #{self.commit_id}"
                if self.comment
                        z << ", !!!#{comment}!!!"
                end
                z << ")"
                z
        end
        def to_s_with_comment()
                self.raise "comment not set" unless comment
                to_s
        end
        def to_json()
                h = Hash.new
                h["repo_spec"] = repo.to_s
                h["commit_id"] = commit_id
                if comment
                        h["comment"] = comment
                end
                JSON.pretty_generate(h)
        end
        def codeline_disk_write()
                repo.codeline_disk_write(self.commit_id)
        end
        def component_contained_by?(cspec_set)
                self.find_commit_for_same_component(cspec_set) != nil
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
                bug_IDs = Cspec.grep_group1(changes, Cspec_set.bug_id_regexp)
                bug_IDs
        end
        def find_commit_for_same_component(cspec_set)
                cspec_set.commits.each do | commit |
                        if commit.repo.eql?(self.repo)
                                return commit
                        end
                end
                return nil
        end
        def repo_and_commit_id()
                "#{self.repo.spec};#{self.commit_id}"
        end
        class << self
                TEST_SOURCE_SERVER_AND_PROJECT_NAME = "orahub.oraclecorp.com;faiza.bounetta/promotion-config"
                TEST_REPO_SPEC = "git;#{TEST_SOURCE_SERVER_AND_PROJECT_NAME};"
                attr_accessor :autodiscovered_deps      #       not for performance so much as to make an infinite loop of dependencies impossible

                def auto_discover_requested_in__repo_and_commit_id(repo_and_commit_id)
                        (repo_and_commit_id =~ AUTODISCOVER_REGEX)
                end 
                def list_changes_between(commit_spec1, commit_spec2)
                        commit1 = Cspec.from_repo_and_commit_id(commit_spec1)
                        commit2 = Cspec.from_repo_and_commit_id(commit_spec2)
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
                                repo_spec = Repo.make_spec(source_control_server, repo_name, branch, change_tracker_host_and_port)
                        else
                                repo_spec = h.get("repo_spec")
                                commit_id = h.get("commit_id")
                        end
                        Cspec.new(repo_spec, commit_id)
                end
                def from_s(s, arg_name="Cspec.from_s")
                        if s.start_with?('http')
                                url = s
                                return from_s(U.rest_get(url), "#{arg_name} => #{url}")
                        end
                        if Cspec.is_repo_and_commit_id?(s)
                                repo_and_commit_id = s
                                if repo_and_commit_id !~ /(.*);([0-9a-f]+)$/
                                        Error_holder.raise("could not parse repo_and_commit_id=#{repo_and_commit_id}")
                                end
                                repo_spec, commit_id = $1, $2
                        else
                                json_text = s
                                begin
                                        json_obj = Json_obj.new(json_text)
                                rescue JSON::ParserError => jpe
                                        Error_holder.raise("trouble parsing #{arg_name} \"#{s}\": #{jpe.to_s}", 400)
                                end
                                # puts "gc from_s: #{json_text}"
                                # gc fromjson: {"repo_spec" : "git;git.osn.oraclecorp.com;osn/cec-server-integration;master","commit_id" : "2bc0b1a58a9277e97037797efb93a2a94c9b6d99"}
                                repo_spec = json_obj.get("repo_spec")
                                commit_id = json_obj.get("commit_id")
                        end
                        Cspec.new(repo_spec, commit_id)
                end
                def from_repo_and_commit_id(repo_and_commit_id, comment=nil)
                        z = repo_and_commit_id.sub(AUTODISCOVER_REGEX, '')
                        if z !~ /(.*);(\w*)$/
                                raise "could not parse #{z}"
                        end
                        repo_spec, commit_id = $1, $2
                        gr = Repo.new(repo_spec)
                        if commit_id == ""
                                commit_id = gr.latest_commit_id
                        end
                        Cspec.new(gr, commit_id, comment)
                end
                def is_repo_and_commit_id?(s)
                        # git;git.osn.oraclecorp.com;osn/cec-server-integration;master;aaaaaaaaaaaa
                        # type         ;  host   ; proj     ;brnch;commit_id
                        if s =~ /^(\w+);([-\w\.]+);([-\w\.\/]+);(\w*);(\w+)\+?$/
                                true
                        else
                                false
                        end
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
                        commit1 = Cspec.from_repo_and_commit_id(commit_spec1)
                        commit2 = Cspec.from_repo_and_commit_id(commit_spec2)
                        return commit2.list_files_changed_since(commit1)
                end
                def test_list_changes_since()
                        compound_spec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;6b5ed0226109d443732540fee698d5d794618b64"
                        compound_spec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                        gc1 = Cspec.from_repo_and_commit_id(compound_spec1)
                        gc2 = Cspec.from_repo_and_commit_id(compound_spec2)
                        changes = gc2.list_changes_since(gc1)
                        changes2 = Cspec.list_changes_between(compound_spec1, compound_spec2)
                        U.assert_eq(changes, changes2, "Cspec.test_list_changes_since - vfy same result from wrapper 0")

                        g1b = Cspec.from_repo_and_commit_id("git;git.osn.oraclecorp.com;osn/cec-server-integration;master;22ab587dd9741430c408df1f40dbacd56c657c3f")
                        g1a = Cspec.from_repo_and_commit_id("git;git.osn.oraclecorp.com;osn/cec-server-integration;master;7dfff5f400b3011ae2c4aafac286d408bce11504")

                        U.assert_eq([gc2, g1b, g1a], changes, "test_list_changes_since")
                end
                def test_list_files_changed_since()
                        compound_spec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;6b5ed0226109d443732540fee698d5d794618b64"
                        compound_spec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                        gc1 = Cspec.from_repo_and_commit_id(compound_spec1)
                        gc2 = Cspec.from_repo_and_commit_id(compound_spec2)

                        changed_files = gc2.list_files_changed_since(gc1)
                        changed_files2 = Cspec.list_files_changed_between(compound_spec1, compound_spec2)
                        U.assert_eq(changed_files, changed_files2, "vfy same result from wrapper 1")
                        U.assert_json_eq({"git;git.osn.oraclecorp.com;osn/cec-server-integration;master" => ["component.properties", "deps.gradle"]}, changed_files, "Cspec.test_list_files_changed_since")
                end
                def test_json()
                        repo_spec = "git;git.osn.oraclecorp.com;osn/cec-server-integration;master"
                        valentine_commit_id = "2bc0b1a58a9277e97037797efb93a2a94c9b6d99"
                        gc = Cspec.new(repo_spec, valentine_commit_id)
                        json = gc.to_json
                        U.assert_json_eq('{"repo_spec":"git;git.osn.oraclecorp.com;osn/cec-server-integration;master","commit_id":"2bc0b1a58a9277e97037797efb93a2a94c9b6d99"}', json, 'Cspec.test_json')
                        gc2 = Cspec.from_s(json)
                        U.assert_eq(gc, gc2, "test ability to export to json, then import from that json back to the same object")
                end
                def test_list_bug_IDs_since()
                        # I noticed that for the commits in this range, there is a recurring automated comment "caas.build.pl.master/3013/" -- so
                        # I thought I would reset the pattern to treat that number like a bug ID for the purposes of the test.
                        # (At some point, i'll need to go find a comment that really does refer to a bug ID.)
                        saved_bug_id_regexp = Cspec_set.bug_id_regexp_val
                        begin
                                compound_spec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;6b5ed0226109d443732540fee698d5d794618b64"
                                compound_spec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                                gc1 = Cspec.from_repo_and_commit_id(compound_spec1)
                                gc2 = Cspec.from_repo_and_commit_id(compound_spec2)
                                Cspec_set.bug_id_regexp_val = Regexp.new(".*caas.build.pl.master/(\\d+)/.*", "m")
                                bug_IDs = gc2.list_bug_IDs_since(gc1)
                                U.assert_eq(["3013", "3012", "3011"], bug_IDs, "test_list_bug_IDs_since")

                                bug_IDs2 = Cspec_set.list_bug_IDs_between(compound_spec1, compound_spec2)
                                U.assert_eq(bug_IDs, bug_IDs2, "test_list_bug_IDs_between wrapper")
                        ensure
                                Cspec_set.bug_id_regexp_val = saved_bug_id_regexp
                        end
                end
                def test()
                        U.assert_eq(true, Cspec.is_repo_and_commit_id?("git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed"), "Cspec.is_repo_and_commit_id")
                        U.assert_eq(true, Cspec.is_repo_and_commit_id?("git;git.osn.oraclecorp.com;osn/cec-server-integration;master;2bc0b1a58a9277e97037797efb93a2a94c9b6d99"), "Cspec.is_repo_and_commit_id 2")

                        test_list_bug_IDs_since()
                        test_list_changes_since()

                        gc1 = Cspec.new(TEST_REPO_SPEC, "dc68aa99903505da966358f96c95f946901c664b")
                        gc2 = Cspec.new(TEST_REPO_SPEC, "42f2d95f008ea14ea3bb4487dba8e3e74ce992a1")
                        gc1_file_list = gc1.list_files
                        gc2_file_list = gc2.list_files
                        U.assert_eq(713, gc1_file_list.size, "Cspec.test gc1_file_list_size")
                        U.assert_eq(713, gc2_file_list.size, "Cspec.test gc2_file_list_size")
                        U.assert_eq(".gitignore", gc1_file_list[0], "Cspec.test gc1_file0")
                        U.assert_eq(".gitignore", gc2_file_list[0], "Cspec.test gc2_file0")
                        U.assert_eq("version.txt", gc1_file_list[712], "Cspec.test gc1_712")
                        U.assert_eq("version.txt", gc2_file_list[712], "Cspec.test gc2_712")
                        gc1_added_or_changed_file_list = gc1.list_files_added_or_updated
                        gc2_added_or_changed_file_list = gc2.list_files_added_or_updated
                        U.assert_eq(0, gc1_added_or_changed_file_list.size, "Cspec.test gc1_added_or_changed_file_list")
                        U.assert_eq(1, gc2_added_or_changed_file_list.size, "Cspec.test gc2_added_or_changed_file_list")
                        U.assert_eq("src/main/java/com/oracle/syseng/configuration/repository/IntegrationRepositoryImpl.java", gc2_added_or_changed_file_list[0], "Cspec.test gc1_added_or_changed0")
                        cc1 = Cspec_set.from_s(<<-EOS)
                        {
                        "cspec": "#{TEST_REPO_SPEC};dc68aa99903505da966358f96c95f946901c664b",
                        "cspec_deps": [] }
                        EOS

                        cc2 = Cspec_set.from_s(<<-EOS)
                        {
                        "cspec": "#{TEST_REPO_SPEC};42f2d95f008ea14ea3bb4487dba8e3e74ce992a1",
                        "cspec_deps": []}
                        EOS

                        U.assert_eq(1, cc1.commits.size, "Cspec.test cc1.commits.size")
                        U.assert_eq(1, cc2.commits.size, "Cspec.test cc2.commits.size")
                        U.assert_eq(gc1, cc1.commits[0], "cc1 commit")
                        U.assert_eq(gc2, cc2.commits[0], "cc2 commit")
                        U.assert_eq([], cc2.find_commits_for_components_that_were_added_since(cc1), "cc2 added commits")

                        U.assert_eq([], cc1.find_commits_for_components_that_were_added_since(cc2), "cc1 added commits")

                        changed_commits1 = cc1.find_commits_for_components_that_changed_since(cc2)
                        changed_commits2 = cc2.find_commits_for_components_that_changed_since(cc1)
                        U.assert_eq(1, changed_commits1.size, 'cc1 size ck')
                        U.assert_eq(1, changed_commits2.size, 'cc2 size ck')
                        U.assert_eq(gc1, changed_commits1[0], 'gc1 json ck')
                        U.assert_eq(gc2, changed_commits2[0], 'gc2 json ck')
                        test_json
                        test_list_files_changed_since()
                end
        end
end

class Cspec_set < Error_holder
        attr_accessor :top_commit
        attr_accessor :dependency_commits

        def initialize(top_commit, dependency_commits)
                if top_commit.is_a?(String)
                        self.top_commit = Cspec.from_repo_and_commit_id(top_commit)
                else
                        self.top_commit = top_commit
                end
                if !dependency_commits
                        self.dependency_commits = []
                else
                        raise "bad dependency_commits=#{dependency_commits}" unless dependency_commits.respond_to?(:size)
                        self.dependency_commits = dependency_commits
                end
        end
        def eql?(other)
                self.top_commit.eql?(other.top_commit) && dependency_commits.eql?(other.dependency_commits)
        end
        def to_json()
                h = Hash.new
                h["cspec"] = top_commit.repo_and_commit_id
                cspec_deps = []
                self.dependency_commits.each do | commit |
                        cspec_deps << commit.repo_and_commit_id
                end
                h["cspec_deps"] = cspec_deps
                JSON.pretty_generate(h)
        end
        def commits()
                z = []
                z << self.top_commit
                if self.dependency_commits
                        z = z.concat(self.dependency_commits)
                end
                z
        end
        def list_files_changed_since(other_cspec_set)
                commits = list_changes_since(other_cspec_set)
                fss = File_sets.new
                commits.each do | commit |
                        fss.add_set(commit.list_changed_files)
                end
                return fss
        end
        def list_changes_since(other_cspec_set)
                pairs = get_pairs_of_commits_with_matching_repo(other_cspec_set)
                changes = []
                pairs.each do | pair |
                        commit0 = pair[0]
                        commit1 = pair[1]
                        changes += commit1.list_changes_since(commit0)
                end
                changes
        end
        def get_pairs_of_commits_with_matching_repo(other_cspec_set)
                pairs = []
                self.commits.each do | commit |
                        previous_commit_for_same_component = commit.find_commit_for_same_component(other_cspec_set)
                        if previous_commit_for_same_component
                                pairs << [ previous_commit_for_same_component, commit ]
                        end
                end
                pairs
        end
        def list_bug_IDs_since(other_cspec_set)
                changes = list_changes_since(other_cspec_set)
                bug_IDs = Cspec.grep_group1(changes, Cspec_set.bug_id_regexp)
                bug_IDs
        end
        def find_commits_for_components_that_were_added_since(other_cspec_set)
                commits_for_components_that_were_added = []
                self.commits.each do | commit |
                        if !commit.component_contained_by?(other_cspec_set)
                                commits_for_components_that_were_added << commit
                        end
                end
                commits_for_components_that_were_added
        end
        def find_commits_for_components_that_changed_since(other_cspec_set)
                commits_for_components_that_changed = []
                self.commits.each do | commit |
                        previous_commit_for_same_component = commit.find_commit_for_same_component(other_cspec_set)
                        if previous_commit_for_same_component
                                commits_for_components_that_changed << commit
                        end
                end
                commits_for_components_that_changed
        end
        def list_files_added_or_updated_since(other_cspec_set)
                commits_for_components_that_were_added   = self.find_commits_for_components_that_were_added_since(other_cspec_set)
                commits_which_were_updated               = self.find_commits_for_components_that_changed_since(other_cspec_set)

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
                z = "Cspec_set(#{self.top_commit}/["
                self.dependency_commits.each do | commit |
                        z << " " << commit.to_s
                end
                z << "]"
                z
        end
        def Cspec_set.list_bug_IDs_between(cspec_set_s1, cspec_set_s2)
                cspec_set1 = Cspec_set.from_repo_and_commit_id(cspec_set_s1)
                cspec_set2 = Cspec_set.from_repo_and_commit_id(cspec_set_s2)
                return cspec_set2.list_bug_IDs_since(cspec_set1)
        end
        def Cspec_set.list_changes_between(cspec_set_s1, cspec_set_s2)
                cspec_set1 = Cspec_set.from_repo_and_commit_id(cspec_set_s1)
                cspec_set2 = Cspec_set.from_repo_and_commit_id(cspec_set_s2)
                return cspec_set2.list_changes_since(cspec_set1)
        end
        def Cspec_set.list_files_changed_between(cspec_set_s1, cspec_set_s2)
                cspec_set1 = Cspec_set.from_repo_and_commit_id(cspec_set_s1)
                cspec_set2 = Cspec_set.from_repo_and_commit_id(cspec_set_s2)
                return cspec_set2.list_files_changed_since(cspec_set1)
        end
        def Cspec_set.list_last_changes(repo_spec, n)
                gr = Repo.new(repo_spec)
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
                        if commit_log_entry !~ /^([a-f0-9]+):(.*)$/m
                                raise "could not understand #{commit_log_entry}"
                        else
                                commit_id, comment = $1, $2
                                commit = Cspec.new(gr, commit_id)
                                commit.comment = comment
                                commits << commit
                        end
                end
                commits
        end
        def Cspec_set.bug_id_regexp()
                if !Cspec_set.bug_id_regexp_val
                        z = Global.get("bug_id_regexp_val", ".*Bug (.*).*")
                        Cspec_set.bug_id_regexp_val = Regexp.new(z, "m")
                end
                Cspec_set.bug_id_regexp_val
        end
        def Cspec_set.from_file(json_fn)
                from_s(IO.read(json_fn))
        end
        def Cspec_set.from_s(s, arg_name="Cspec_set.from_s", autodiscover=false)
                if s.start_with?('http')
                        url = s
                        return from_s(U.rest_get(url), "#{arg_name} => #{url}")
                end
                deps = nil
                if Cspec.is_repo_and_commit_id?(s)
                        repo_and_commit_id = s
                else
                        if s !~ /\{/
                                Error_holder.raise("expecting JSON, but I see no hash in #{s}", 400)
                        end
                        begin
                                h = JSON.parse(s)
                        rescue JSON::ParserError => jpe
                                Error_holder.raise("trouble parsing #{arg_name} \"#{s}\": #{jpe.to_s}", 400)
                        end
                        repo_and_commit_id = h["cspec"]
                        Error_holder.raise("expected a value for JSON key 'cspec' in #{s}", 400) unless repo_and_commit_id
                        if h.has_key?("cspec_deps")
                                array_of_dep_cspec = h["cspec_deps"]
                                deps = []
                                array_of_dep_cspec.each do | dep_cspec |
                                        cs = Cspec_set.from_s(dep_cspec)
                                        deps += cs.commits
                                end
                        end
                end
                if Cspec.auto_discover_requested_in__repo_and_commit_id(repo_and_commit_id)
                        autodiscover = true
                end
                cs = Cspec_set.new(repo_and_commit_id, deps)
                if !deps && autodiscover
                        # executes auto-discovery in this case
                        cs.dependency_commits = cs.top_commit.unreliable_autodiscovery_of_dependencies_from_build_configuration
                end
                cs
        end
        def Cspec_set.from_repo_and_commit_id(repo_and_commit_id, dependency_commits=nil)
                if repo_and_commit_id =~ /\+$/
                        autodiscover = true
                elsif dependency_commits == Cspec::AUTODISCOVER
                        puts "AU ----"
                        autodiscover = true
                else
                        autodiscover = false
                end
                top_commit = Cspec.from_repo_and_commit_id(repo_and_commit_id)
                if autodiscover
                        dependency_commits = top_commit.unreliable_autodiscovery_of_dependencies_from_build_configuration
                end
                Cspec_set.new(top_commit, dependency_commits)
        end
        def Cspec_set.test_list_changes_since()
                compound_spec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;6b5ed0226109d443732540fee698d5d794618b64"
                compound_spec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                cc1 = Cspec_set.from_repo_and_commit_id(compound_spec1)
                cc2 = Cspec_set.from_repo_and_commit_id(compound_spec2)

                gc2 = Cspec.from_repo_and_commit_id(compound_spec2)

                changes = cc2.list_changes_since(cc1)
                changes2 = Cspec_set.list_changes_between(compound_spec1, compound_spec2)
                U.assert_eq(changes, changes2, "vfy same result from wrapper 2a")

                g1b = Cspec.from_repo_and_commit_id("git;git.osn.oraclecorp.com;osn/cec-server-integration;master;22ab587dd9741430c408df1f40dbacd56c657c3f")
                g1a = Cspec.from_repo_and_commit_id("git;git.osn.oraclecorp.com;osn/cec-server-integration;master;7dfff5f400b3011ae2c4aafac286d408bce11504")


                U.assert_eq(gc2, changes[0], "test_list_changes_since.0")
                U.assert_eq(g1b, changes[1], "test_list_changes_since.1")
                U.assert_eq(g1a, changes[2], "test_list_changes_since.2")
        end
        def Cspec_set.test_list_files_changed_since()
                compound_spec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;6b5ed0226109d443732540fee698d5d794618b64+"
                compound_spec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e+"
                cc1 = Cspec_set.from_repo_and_commit_id(compound_spec1, Cspec::AUTODISCOVER)
                cc2 = Cspec_set.from_repo_and_commit_id(compound_spec2, Cspec::AUTODISCOVER)

                changed_files2 = Cspec_set.list_files_changed_between(compound_spec1, compound_spec2)
                changed_files = cc2.list_files_changed_since(cc1)
                
                U.assert_eq(changed_files, changed_files2, "vfy same result from wrapper 2b")

                expected_changed_files = {
                "git;git.osn.oraclecorp.com;osn/cec-server-integration;master" => [ "component.properties", "deps.gradle"],
                "git;git.osn.oraclecorp.com;ccs/caas;master" => [ "component.properties", "deps.gradle"]
                }

                U.assert_json_eq(expected_changed_files, changed_files, "Cspec_set.test_list_files_changed_since")
        end
        def Cspec_set.test_list_bug_IDs_since()
                # I noticed that for the commits in this range, there is a recurring automated comment "caas.build.pl.master/3013/" -- so
                # I thought I would reset the pattern to treat that number like a bug ID for the purposes of the test.
                # (At some point, i'll need to go find a comment that really does refer to a bug ID.)
                saved_bug_id_regexp = Cspec_set.bug_id_regexp_val
                begin
                        compound_spec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;6b5ed0226109d443732540fee698d5d794618b64"
                        compound_spec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                        gc1 = Cspec_set.from_repo_and_commit_id(compound_spec1)
                        gc2 = Cspec_set.from_repo_and_commit_id(compound_spec2)
                        Cspec_set.bug_id_regexp_val = Regexp.new(".*caas.build.pl.master/(\\d+)/.*", "m")
                        bug_IDs = gc2.list_bug_IDs_since(gc1)
                        U.assert_eq(["3013", "3012", "3011"], bug_IDs, "bug_IDs_since")
                ensure
                        Cspec_set.bug_id_regexp_val = saved_bug_id_regexp
                end
        end
        def Cspec_set.test_json_export()
                json = Cspec_set.from_s("git;git.osn.oraclecorp.com;osn/cec-server-integration;master;2bc0b1a58a9277e97037797efb93a2a94c9b6d99", "Cspec_set.test_json_export", true).to_json
                U.assert_json_eq_f(json, "Cspec_set.test_json_export")
                json = Cspec_set.from_s("git;git.osn.oraclecorp.com;osn/cec-server-integration;master;2bc0b1a58a9277e97037797efb93a2a94c9b6d99").to_json
                U.assert_json_eq_f(json, "Cspec_set.test_json_export__without_autodiscover")
        end
        def Cspec_set.test_full_cspec_set_as_dep()
                U.assert_json_eq_f(Cspec_set.from_s(Json_change_tracker.load_local("test_full_cspec_set_as_dep.json")).to_json, "test_full_cspec_set_as_dep")
        end
        def Cspec_set.test()
                test_list_files_changed_since()
                test_json_export()
                repo_spec = "git;git.osn.oraclecorp.com;osn/cec-server-integration;master"
                valentine_commit_id = "2bc0b1a58a9277e97037797efb93a2a94c9b6d99"
                cc = Cspec_set.from_repo_and_commit_id("#{repo_spec};#{valentine_commit_id}", Cspec::AUTODISCOVER)
                U.assert(cc.dependency_commits.size > 0, "cc.dependency_commits.size > 0")
                json = cc.to_json
                U.assert_json_eq_f(json, "dependency_gather1")

                cc2 = Cspec_set.from_s(json)
                U.assert_eq(cc, cc2, "json copy dependency_gather1")

                cc9 = Cspec_set.from_repo_and_commit_id("git;git.osn.oraclecorp.com;osn/cec-server-integration;;2bc0b1a58a9277e97037797efb93a2a94c9b6d99", Cspec::AUTODISCOVER)
                U.assert_json_eq_f(cc9.to_json, "cc9.to_json")

                test_list_changes_since()
                test_list_bug_IDs_since()
                test_full_cspec_set_as_dep()
        end
        class << self
                attr_accessor :bug_id_regexp_val
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
