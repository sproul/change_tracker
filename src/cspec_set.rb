require_relative 'cspec'
require_relative 'cspec_span_report_item'

class Cspec_pair
        attr_accessor :cspec1
        attr_accessor :cspec2
        def initialize(cspec1, cspec2)
                self.cspec1 = cspec1
                self.cspec2 = cspec2
	end
        def to_s()
                if cspec1 && cspec2
                        if cspec1.eql?(cspec2)
                                "#{cspec1} did not change"
                        else
                                "#{cspec1} changed to #{cspec2.to_s.sub(/.*;/, "")}"
                        end
                elsif cspec2
                        "#{cspec2} was added"
                elsif cspec1
                        "#{cspec1} was removed"
                end
        end
        def <=>(other_cspec_pair)
                self.to_s.<=>(other_cspec_pair.to_s)
        end
	class << self
                def test()
                        cspec1 = Cspec.new(Cspec::TEST_REPO_SPEC, "11111111111")
                        cspec2 = Cspec.new(Cspec::TEST_REPO_SPEC, "22222222222")
                        U.assert_eq("git;orahub.oraclecorp.com;faiza.bounetta/promotion-config;;11111111111 did not change", Cspec_pair.new(cspec1, cspec1).to_s, "unchanged Cspec_pair")
                        U.assert_eq("git;orahub.oraclecorp.com;faiza.bounetta/promotion-config;;11111111111 changed to 22222222222", Cspec_pair.new(cspec1, cspec2).to_s, "changed Cspec_pair")
                        U.assert_eq("git;orahub.oraclecorp.com;faiza.bounetta/promotion-config;;11111111111 was added", Cspec_pair.new(nil, cspec1).to_s, "added component Cspec_pair")
                        U.assert_eq("git;orahub.oraclecorp.com;faiza.bounetta/promotion-config;;11111111111 was removed", Cspec_pair.new(cspec1, nil).to_s, "removed component Cspec_pair")
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
        # assemble a list of pairs of commits which show how the components making up a Cspec_set have evolved
        #
        # For each component represented by a cspec_set, there is a cspec.  Given self (a Cspec_set) and other_cspec_set,
        # this routine will return a list of pairs of Cspec objects from these sets.
        # 
        # - components which didn't change are represented by a Cspec from each of the 2 Cspec_sets; these Cspec objects will be the same
        # - components which changed are represented by a Cspec from each of the 2 Cspec_sets, each showing the head revision for its corresponding pcar
        # - components which were added will be represented by [ nil, Cspec ]
        # - components which were removed will be represented by [ Cspec, nil ]
        def list_component_cspec_pairs(other_cspec_set)
                commit_pairs = []
                self.commits.each do | commit |
                        previous_commit_for_same_component = commit.find_commit_for_same_component(other_cspec_set)
                        commit_pairs << Cspec_pair.new(previous_commit_for_same_component, commit)
                end
                other_cspec_set.commits.each do | commit |
                        following_commit_for_same_component = commit.find_commit_for_same_component(self)
                        if ! following_commit_for_same_component
                                commit_pairs << Cspec_pair.new(commit, nil)
                        end
                end
                commit_pairs.sort
        end
        def list_files_changed_since(other_cspec_set)
                pairs = get_pairs_of_commits_with_matching_repo(other_cspec_set)
                report_item_set = Cspec_span_report_item_set.new
                pairs.each do | pair |
                        commit0 = pair[0]
                        commit1 = pair[1]
                        report_item_set.add(commit1.list_files_changed_since(commit0))
                end
                report_item_set
        end
        def list_changes_since(other_cspec_set)
                pairs = get_pairs_of_commits_with_matching_repo(other_cspec_set)
                report_item_set = Cspec_span_report_item_set.new
                pairs.each do | pair |
                        commit0 = pair[0]
                        commit1 = pair[1]
                        report_item_set.add(commit1.list_changes_since(commit0))
                end
                report_item_set
        end
        def get_pairs_of_commits_with_matching_repo(other_cspec_set)
                pairs = []
                self.commits.each do | commit |
                        previous_commit_for_same_component = commit.find_commit_for_same_component(other_cspec_set)
                        if previous_commit_for_same_component
                                if previous_commit_for_same_component.commit_id != commit.commit_id        # if there is no change, then we can ignore this component
                                        puts "change occurred" if Cspec_set.trace_commit_pairs
                                        pairs << [ previous_commit_for_same_component, commit ]
                                else
                                        puts "no change occurred" if Cspec_set.trace_commit_pairs
                                end
                        end
                end
                puts "get_pairs_of_commits_with_matching_repo: pairs.length=#{pairs.length}" if Cspec_set.trace_commit_pairs
                pairs
        end
        def list_bug_IDs_since(other_cspec_set)
                report_item_set = list_changes_since(other_cspec_set)
                bug_ID_report_item_set = Cspec_span_report_item_set.new
                report_item_set.items.each do | report_item |
                        if report_item.item == Cspec_span_report_item::INCOMPARABLE
                                bug_ID_report_item_set.add(report_item)
                        else
                                bug_IDs = Cspec.grep_group1(report_item.item, Cspec_set.bug_id_regexp)
                                if !bug_IDs.empty?
                                        report_item.item = bug_IDs
                                        bug_ID_report_item_set.add(report_item)
                                end
                        end
                end
                bug_ID_report_item_set
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
                cspec_set1 = Cspec_set.from_s(cspec_set_s1)
                cspec_set2 = Cspec_set.from_s(cspec_set_s2)
                return cspec_set2.list_bug_IDs_since(cspec_set1)
        end
        def Cspec_set.list_changes_between(cspec_set_s1, cspec_set_s2)
                cspec_set1 = Cspec_set.from_s(cspec_set_s1)
                cspec_set2 = Cspec_set.from_s(cspec_set_s2)
                return cspec_set2.list_changes_since(cspec_set1)
        end
        def Cspec_set.list_files_changed_between(cspec_set_s1, cspec_set_s2)
                cspec_set1 = Cspec_set.from_s(cspec_set_s1)
                cspec_set2 = Cspec_set.from_s(cspec_set_s2)
                return cspec_set2.list_files_changed_since(cspec_set1)
        end
        def Cspec_set.list_components_between(cspec_set_s1, cspec_set_s2)
                cspec_set1 = Cspec_set.from_s(cspec_set_s1)
                cspec_set2 = Cspec_set.from_s(cspec_set_s2)
                return cspec_set2.list_component_cspec_pairs(cspec_set1)
        end
        def Cspec_set.list_last_changes(repo_spec, n)
                gr = Repo.from_spec(repo_spec)
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
                if !File.exist?(json_fn)
                        if File.exist?("#{U.initial_working_directory}/#{json_fn}")
                                json_fn = "#{U.initial_working_directory}/#{json_fn}"
                        else
                                raise "could not find #{json_fn} in #{Dir.pwd}"
                        end 
                end
                from_s(IO.read(json_fn))
        end
        def Cspec_set.from_file_or_url(json_path)
                from_s(U.read_file_or_url(json_path))
        end
        def Cspec_set.from_json_obj_v1(z)
                if !z.respond_to?(:has_key?)
                        cs0 = nil
                else
                        deps = []
                        if z.has_key?("cspec")
                                cs0 = Cspec_set.from_s(z["cspec"])
                        else
                                cs0 = nil
                        end
                        if z.has_key?("cspec_deps")
                                Error_holder.raise("since there is a cspec_deps value, there should also be a cspec value, but it is missing in #{s}", 400) unless cs0
                                
                                deps = []
                                z["cspec_deps"].each do | dep_cspec |
                                        cs = Cspec_set.from_s(dep_cspec)
                                        deps += cs.commits
                                end
                                cs0.dependency_commits = deps
                        end
                end
                cs0
        end
        def Cspec_set.from_json_obj_v2(z)
                
                cspec_set_array = z.map do | cspec_h |
                        if !cspec_h.has_key?("cspec")
                                Error_holder.raise("expected a cspec key in the hash #{cspec_h} (from #{z})", 400)
                        end
                        #if cspec_h["cspec"] == "git;git.osn.oraclecorp.com;osn/desktop;master;null"
                        #        raise "lskdjf"
                        #end
                        cs = Cspec_set.from_s(cspec_h["cspec"])
                        cspec_h.each_pair do | key, val |
                                if key != "cspec"
                                        cs.top_commit.add_prop(key, val)
                                end
                        end
                        cs
                end
                cs0 = cspec_set_array.shift
                cspec_set_array.each do | csx |
                        cs0.dependency_commits += csx.commits
                end
                
                cs0
        end
        def Cspec_set.from_json_obj(z)
                t = Cspec_set.from_json_obj_v1(z)
                if !t
                        t = Cspec_set.from_json_obj_v2(z)
                end
                t
        end
        def Cspec_set.from_s(s, arg_name="Cspec_set.from_s", autodiscover=false)
                if s.start_with?('http')
                        url = s
                        return from_s(U.rest_get(url), "#{arg_name} => #{url}")
                end
                deps = nil
                if Cspec.is_repo_and_commit_id?(s)
                        repo_and_commit_id = s
                        cs = Cspec_set.new(repo_and_commit_id, nil)
                else
                        if s !~ /\{/
                                Error_holder.raise("expecting JSON, but I see no hash in #{s}", 400)
                        end
                        begin
                                h = JSON.parse(s)
                        rescue JSON::ParserError => jpe
                                Error_holder.raise("trouble parsing #{arg_name} \"#{s}\": #{jpe.to_s}", 400)
                        end
                        cs = from_json_obj(h)
                end
                if Cspec.auto_discover_requested_in__repo_and_commit_id(repo_and_commit_id)
                        autodiscover = true
                end
                if autodiscover && (!deps || deps.empty?)
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
                compound_spec1 = "git;git.osn.oraclecorp.com;osn/serverintegration;;6b5ed0226109d443732540fee698d5d794618b64"
                compound_spec2 = "git;git.osn.oraclecorp.com;osn/serverintegration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                cc1 = Cspec_set.from_repo_and_commit_id(compound_spec1)
                cc2 = Cspec_set.from_repo_and_commit_id(compound_spec2)

                gc2 = Cspec.from_repo_and_commit_id(compound_spec2)

                report_item_set1 = cc2.list_changes_since(cc1)
                report_item_set2 = Cspec_set.list_changes_between(compound_spec1, compound_spec2)
                changes1 = report_item_set1.all_items
                changes2 = report_item_set2.all_items
                U.assert_eq(changes1, changes2, "vfy same result from wrapper 2a")

                g1b = Cspec.from_repo_and_commit_id("git;git.osn.oraclecorp.com;osn/serverintegration;master;22ab587dd9741430c408df1f40dbacd56c657c3f")
                g1a = Cspec.from_repo_and_commit_id("git;git.osn.oraclecorp.com;osn/serverintegration;master;7dfff5f400b3011ae2c4aafac286d408bce11504")


                U.assert_eq(gc2, changes1[0], "test_list_changes_since.0")
                U.assert_eq(g1b, changes1[1], "test_list_changes_since.1")
                U.assert_eq(g1a, changes1[2], "test_list_changes_since.2")
        end
        def Cspec_set.test_list_files_changed_since_cs()
                compound_spec1 = "git;git.osn.oraclecorp.com;osn/serverintegration;;6b5ed0226109d443732540fee698d5d794618b64+"
                compound_spec2 = "git;git.osn.oraclecorp.com;osn/serverintegration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e+"
                cc1 = Cspec_set.from_repo_and_commit_id(compound_spec1, Cspec::AUTODISCOVER)
                cc2 = Cspec_set.from_repo_and_commit_id(compound_spec2, Cspec::AUTODISCOVER)

                report_item_set = Cspec_set.list_files_changed_between(compound_spec1, compound_spec2)
                changed_files2 = report_item_set.all_items
                changed_files = cc2.list_files_changed_since(cc1).all_items
                cc2.list_component_cspec_pairs(cc1)
                
                U.assert_eq(changed_files, changed_files2, "vfy same result from wrapper 2b")

                expected_changed_files = [ "component.properties", "deps.gradle", "component.properties", "deps.gradle" ]
                U.assert_json_eq(expected_changed_files, changed_files, "Cspec_set.test_list_files_changed_since_cs")
        end
        def Cspec_set.test_list_bug_IDs_since()
                # I noticed that for the commits in this range, there is a recurring automated comment "caas.build.pl.master/3013/" -- so
                # I thought I would reset the pattern to treat that number like a bug ID for the purposes of the test.
                # (At some point, i'll need to go find a comment that really does refer to a bug ID.)
                saved_bug_id_regexp = Cspec_set.bug_id_regexp_val
                begin
                        compound_spec1 = "git;git.osn.oraclecorp.com;osn/serverintegration;;6b5ed0226109d443732540fee698d5d794618b64"
                        compound_spec2 = "git;git.osn.oraclecorp.com;osn/serverintegration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                        gc1 = Cspec_set.from_repo_and_commit_id(compound_spec1)
                        gc2 = Cspec_set.from_repo_and_commit_id(compound_spec2)
                        Cspec_set.bug_id_regexp_val = Regexp.new(".*caas.build.pl.master/(\\d+)/.*", "m")
                        bug_IDs = gc2.list_bug_IDs_since(gc1).all_items
                        U.assert_eq(["3013", "3012", "3011"], bug_IDs, "bug_IDs_since")
                ensure
                        Cspec_set.bug_id_regexp_val = saved_bug_id_regexp
                end
        end
        def Cspec_set.test_json_export()
                json = Cspec_set.from_s("git;git.osn.oraclecorp.com;osn/serverintegration;master;2bc0b1a58a9277e97037797efb93a2a94c9b6d99", "Cspec_set.test_json_export", true).to_json
                U.assert_json_eq_f(json, "Cspec_set.test_json_export")
                json = Cspec_set.from_s("git;git.osn.oraclecorp.com;osn/serverintegration;master;2bc0b1a58a9277e97037797efb93a2a94c9b6d99").to_json
                U.assert_json_eq_f(json, "Cspec_set.test_json_export__without_autodiscover")
        end
        def Cspec_set.test_full_cspec_set_as_dep()
                U.assert_json_eq_f(Cspec_set.from_s(Json_change_tracker.load_local("test_full_cspec_set_as_dep.json")).to_json, "test_full_cspec_set_as_dep")
        end
        def Cspec_set.test_reading_attributes()
                cs = Cspec_set.from_s(U.read_file("public/test_cspec_set1_v2.json"))
                U.assert_eq("first one", cs.top_commit.props["a1"], "test_reading_attributes.a1")
                U.assert_eq(2, cs.top_commit.props.size, "test_reading_attributes.size for #{cs.top_commit.props}")
        end
        def Cspec_set.test_reading_steve_roth_v1()
                cs = Cspec_set.from_file("public/test_steve_roth_v1.json")
                # came from http://artifactory-slc.oraclecorp.com/artifactory/docs-release-local/com/oracle/opc/cec/cec/18.4.3-1808221348/
                component_count = 10
                U.assert_eq("Desktop",   cs.top_commit.props["name"], "Steve Roth attribute on cspec 1")
                U.assert_eq(component_count, cs.commits.length, "component count")
                cs = Cspec_set.from_file("public/cec_18.4.1-1808081448_paas.json")
                component_count = 11
                U.assert_eq("Desktop",   cs.top_commit.props["name"], "Steve Roth attribute on cspec 2")
                U.assert_eq(component_count, cs.commits.length, "component count 2")
                cs = Cspec_set.from_file("public/cec_18.4.3-1808031643_paas.json")
                component_count = 11
                U.assert_eq("Desktop",   cs.top_commit.props["name"], "Steve Roth attribute on cspec 3")
                U.assert_eq(component_count, cs.commits.length, "component count 3")
        end
        #def Cspec_set.test_cf_steve_roth_v23()
        ### files pulled from under http://artifactory-slc.oraclecorp.com/artifactory/docs-release-local/com/oracle/opc/cec/cec/
        ##cs1 = Cspec_set.from_file("public/cec_18.3.5-1808091203_paas.json")
        ##cs2 = Cspec_set.from_file("public/cec_18.4.1-1808081448_paas.json")
        ##report_item_set = cs2.list_files_changed_since(cs1)
        ##U.assert_eq(["blueprints/service/cec.json","provisioning/apns/com.oracle.webcenter.documents.p12","scripts/cecs/provisioning/python/common/common_constants.py","scripts/cecs/provisioning/python/pod/actions/privileged/oit_setup.sh","scripts/cecs/provisioning/python/pod/pod_health_check.py"], report_item_set.all_items, "steve_roth_v23 files changed")
        ##report_item_set = cs2.list_bug_IDs_since(cs1)
        ##z = report_item_set.all_items
        ##U.assert_eq(1, z.length, "steve_roth_v23 bug IDs length")
        ##U.assert_eq('28525388 - Fix health check script to pick payload of create/applypatch/precheckpatch only.', z[0].to_s, "steve_roth_v23 bug ID[0]")
        ##report_item_set = cs2.list_changes_since(cs1)
        ##U.assert_array_to_s_eq([
        ##"git;git.osn.oraclecorp.com;osn/cec_external;;f2cedfe8a577962ccd8d03150ca3ec9b56ed734e",
        ##"git;git.osn.oraclecorp.com;osn/cec_external;;a4f3cd3e4df0084be5adaca4c3181fb7624babc1",
        ##"git;git.osn.oraclecorp.com;osn/cec_external;;66347117d2ad9247ea3a2481bbe226c40a086703",
        ##"git;git.osn.oraclecorp.com;osn/cec_external;;3b9310f6bdc367eb165ead92557f2859d5e95bca",
        ##"git;git.osn.oraclecorp.com;osn/cec_external;;310ca5f299c1ad159a07a05310aab6f083644265",
        ##"git;git.osn.oraclecorp.com;osn/cec_external;;af50effef6862b36055e9c573b2d4aa44ebe6b0d",
        ##"git;git.osn.oraclecorp.com;osn/cec_external;;ff47492f03f04cdd1057b2d9b6d83e18370480df",
        ##"git;git.osn.oraclecorp.com;osn/cec_external;;b967825c672a754f72cc9d1d5d69f21c404ff5c0",
        ##"git;git.osn.oraclecorp.com;osn/cec_external;;25b559910c839f131aae997984886fd717084c84",
        ##"git;git.osn.oraclecorp.com;osn/cec_external;;2370045a5d438483ab53e62b509bdb881c58e273" ], report_item_set.all_items, "steve_roth_v23 changes")
        #end
        def Cspec_set.test_cf_steve_roth_v18_4_3()
                # files pulled from under http://artifactory-slc.oraclecorp.com/artifactory/docs-release-local/com/oracle/opc/cec/cec/
                cs1 = Cspec_set.from_file("public/18.4.3-1808221348_paas.json")
                cs2 = Cspec_set.from_file("public/18.4.3-1808241018_paas.json")
                report_item_set = cs2.list_files_changed_since(cs1)
                U.assert_eq(["blueprints/service/cec.json","provisioning/apns/com.oracle.webcenter.documents.p12","scripts/cecs/provisioning/python/common/common_constants.py","scripts/cecs/provisioning/python/pod/actions/privileged/oit_setup.sh","scripts/cecs/provisioning/python/pod/pod_health_check.py"], report_item_set.all_items, "steve_roth_v18_4_3 files changed")
                report_item_set = cs2.list_bug_IDs_since(cs1)
                z = report_item_set.all_items
                U.assert_eq(1, z.length, "steve_roth_v18_4_3 bug IDs length")
                U.assert_eq('28525388 - Fix health check script to pick payload of create/applypatch/precheckpatch only.', z[0].to_s, "steve_roth_v18_4_3 bug ID[0]")
                report_item_set = cs2.list_changes_since(cs1)
                U.assert_array_to_s_eq([
                "git;git.osn.oraclecorp.com;osn/cec_external;;f2cedfe8a577962ccd8d03150ca3ec9b56ed734e",
                "git;git.osn.oraclecorp.com;osn/cec_external;;a4f3cd3e4df0084be5adaca4c3181fb7624babc1",
                "git;git.osn.oraclecorp.com;osn/cec_external;;66347117d2ad9247ea3a2481bbe226c40a086703",
                "git;git.osn.oraclecorp.com;osn/cec_external;;3b9310f6bdc367eb165ead92557f2859d5e95bca",
                "git;git.osn.oraclecorp.com;osn/cec_external;;310ca5f299c1ad159a07a05310aab6f083644265",
                "git;git.osn.oraclecorp.com;osn/cec_external;;af50effef6862b36055e9c573b2d4aa44ebe6b0d",
                "git;git.osn.oraclecorp.com;osn/cec_external;;ff47492f03f04cdd1057b2d9b6d83e18370480df",
                "git;git.osn.oraclecorp.com;osn/cec_external;;b967825c672a754f72cc9d1d5d69f21c404ff5c0",
                "git;git.osn.oraclecorp.com;osn/cec_external;;25b559910c839f131aae997984886fd717084c84",
                "git;git.osn.oraclecorp.com;osn/cec_external;;2370045a5d438483ab53e62b509bdb881c58e273" ], report_item_set.all_items, "steve_roth_v18_4_3 changes")
        end
        def Cspec_set.test_cf_steve_roth_v23_Desktop_only()
                # taken from  artifactory-slc.oraclecorp.com_artifactory_docs-release-local_com_oracle_opc_cec
                cs1 = Cspec_set.from_file("public/cec_18.3.5-1808091203_paas_Desktop.json")
                cs2 = Cspec_set.from_file("public/cec_18.4.1-1808081448_paas_Desktop.json")
                report_item_set = cs2.list_files_changed_since(cs1)
                U.assert_eq(true, report_item_set.empty?, "comparing same SHA should yield no changes")
        end
        def Cspec_set.test()
                Repo.note_renamed_repo("git;git.osn.oraclecorp.com;osn/cec-server-integration", "git;git.osn.oraclecorp.com;osn/serverintegration")
                test_cf_steve_roth_v23_Desktop_only()
                #test_cf_steve_roth_v23()
                test_cf_steve_roth_v18_4_3()
                test_reading_steve_roth_v1()
                test_json_export()
                test_full_cspec_set_as_dep()                                
                test_reading_attributes()
                test_list_files_changed_since_cs()                
                repo_spec = "git;git.osn.oraclecorp.com;osn/serverintegration;master"
                valentine_commit_id = "2bc0b1a58a9277e97037797efb93a2a94c9b6d99"
                cc = Cspec_set.from_repo_and_commit_id("#{repo_spec};#{valentine_commit_id}", Cspec::AUTODISCOVER)
                U.assert(cc.dependency_commits.size > 0, "cc.dependency_commits.size > 0")
                json = cc.to_json
                U.assert_json_eq_f(json, "dependency_gather1")

                cc2 = Cspec_set.from_s(json)
                U.assert_eq(cc, cc2, "json copy dependency_gather1")

                cc9 = Cspec_set.from_repo_and_commit_id("git;git.osn.oraclecorp.com;osn/serverintegration;;2bc0b1a58a9277e97037797efb93a2a94c9b6d99", Cspec::AUTODISCOVER)
                U.assert_json_eq_f(cc9.to_json, "cc9.to_json")

                test_list_changes_since()
                test_list_bug_IDs_since()
        end
        class << self
                attr_accessor :bug_id_regexp_val
                attr_accessor :trace_commit_pairs
        end
end
