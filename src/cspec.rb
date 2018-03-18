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
