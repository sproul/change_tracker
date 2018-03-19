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
                commit_log_entries = gr.vcs.list_last_changes(n)
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
