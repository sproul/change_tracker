class Cspec < Error_holder
        TEST_SOURCE_SERVER_AND_PROJECT_NAME = "orahub.oraclecorp.com;faiza.bounetta/promotion-config"
        TEST_REPO_SPEC = "git;#{TEST_SOURCE_SERVER_AND_PROJECT_NAME};"
        AUTODISCOVER = "+"              #       autodiscover_dependencies_by_looking_in_codeline
        AUTODISCOVER_REGEX = /\+$/      #       regex to find AUTODISCOVER appended to a repo_and_commit_id
        attr_accessor :commit_id
        attr_accessor :comment  # only set if this object populated by a call to git log
        attr_accessor :props
        attr_accessor :repo
        def initialize(repo_expr, commit_id, comment=nil, props=Hash.new)
                if repo_expr.is_a? String
                        repo_spec = repo_expr
                        self.repo = Repo.from_spec(repo_spec)
                elsif repo_expr.is_a? Repo
                        self.repo = repo_expr
                else
                        self.raise "unexpected repo type #{repo.class}"
                end
                self.commit_id = commit_id
                self.comment = comment
                self.props = props
                puts "Cspec.new(#{self.repo_and_commit_id})" if Cec_gradle_parser.trace_autodiscovery
        end
        def <=>(other)
                self.to_s <=> other.to_s
        end
        def add_prop(key, val)
                self.props[key] = val
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
                return self.repo.vcs.list_changes_since(other_commit, self)
        end
        def list_files_changed_since(other_commit)
                # return Cspec_span_report_item pointing to array of string paths of files changed between this commit and 'other commit'
                if self.repo.vcs.respond_to?(:list_files_changed_since)
                        report_item = Cspec_span_report_item.new(other_commit, self, self.repo.vcs.list_files_changed_since(other_commit, self))
                else
                        report_item = list_changes_since(other_commit)
                        commits = report_item.item
                        changed_file_list = []
                        commits.each do | commit |
                                files_changed_by_commit = commit.repo.vcs.get_changed_files_array(commit.commit_id)
                                changed_file_list.concat(files_changed_by_commit)
                        end
                        report_item.item = changed_file_list.sort.uniq
                end
                return report_item
        end
        def eql?(other)
                other && self.repo.eql?(other.repo) && self.commit_id.eql?(other.commit_id)
        end
        def to_s()
                # "cspec" : "git;alm.oraclecorp.com;odocs/s/odocs_desktop/scm/desktop.git;release/rd129;cbb9a918f6beea1e0b70b9b33c74781f718a5906",
                z = "#{self.repo.source_control_type};#{self.repo.source_control_server};#{self.repo.project_name};"
                if self.repo.branch_name
                        z += self.repo.branch_name
                end
                z += ";#{self.commit_id}"
                # z = "Cspec(#{self.repo.spec}, #{self.commit_id}"
                # if self.comment
                #         z << ", \"#{comment}\""
                # end
                # if self.props && !self.props.empty?
                #         z << ", #{self.props}"
                # end
                # z << ")"
                z
        end
        def to_s_with_comment()
                self.raise "comment not set" unless comment
                to_s
        end
        def to_jsonable_h(show_comment=true)
                h = self.props.clone
                h["repo_spec"] = repo.to_s
                h["commit_id"] = commit_id
                if comment && show_comment
                        h["comment"] = comment
                end
                h
        end
        def to_json(show_comment=true)
                JSON.pretty_generate(self.to_jsonable_h(show_comment))
        end
        def codeline_disk_write()
                if !self.repo.codeline_disk_exist?
                        self.repo.codeline_disk_write(self.commit_id)
                end
                if !self.repo.codeline_disk_exist?
                        self.raise "error: #{self} does not exist on disk after supposed clone"
                end
        end
        def component_contained_by?(cspec_set)
                self.find_commit_for_same_component(cspec_set) != nil
        end
        def list_files_added_or_updated()
                repo.vcs.get_changed_files_array(self.commit_id)
        end
        def list_files()
                repo.vcs.list_files(self.commit_id)
        end
        def list_bug_IDs_since(other_commit)
                report_item = list_changes_since(other_commit)
                changes = report_item.item
                bug_IDs = Cspec.grep_group1(changes, Cspec_set.bug_id_regexp)
                bug_IDs
        end
        def refers_to_same_component_as(other_commit)
                if self.repo.source_control_type == "ade" && other_commit.repo.source_control_type == "ade"
                        return (self.repo.vcs.ade_series == other_commit.repo.vcs.ade_series)
                end
                return self.repo.eql?(other_commit.repo)
        end
        def find_commit_for_same_component(cspec_set)
                cspec_set.commits.each do | commit |
                        # doesn't quite work for ADE, where the repo is tied to a label, but really what we're asking here is
                        # "do these commits refer to the same series?"    Use new method Cspec.refers_to_same_component_as
                        #if commit.repo.eql?(self.repo)
                        if self.refers_to_same_component_as(commit)
                                return commit
                        end
                end
                return nil
        end
        def repo_and_commit_id()
                "#{self.repo.spec};#{self.commit_id}"
        end
        class << self
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
                                source_control_server_and_repo_name = h.get("gitRepoName")
                                branch         = h.get("gitBranch")
                                commit_id      = h.get("gitCommitId")
                                source_control_server, repo_name = source_control_server_and_repo_name.split(/;/)
                                repo_spec = Repo.make_spec("git", source_control_server, repo_name, branch)
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
                                # gc fromjson: {"repo_spec" : "git;git.osn.oraclecorp.com;osn/serverintegration;master","commit_id" : "2bc0b1a58a9277e97037797efb93a2a94c9b6d99"}
                                repo_spec = json_obj.get("repo_spec")
                                commit_id = json_obj.get("commit_id")
                        end
                        Cspec.new(repo_spec, commit_id)
                end
                def from_repo_and_commit_id(repo_and_commit_id, comment=nil)
                        z = repo_and_commit_id.sub(AUTODISCOVER_REGEX, '')
                        if repo_and_commit_id =~ /^ade;(.*)/
                                commit_id = $1
                                repo_spec = repo_and_commit_id
                        elsif z !~ /(.*);(\w*)$/
                                raise "could not parse #{z}"
                        else
                                repo_spec, commit_id = $1, $2
                        end
                        gr = Repo.from_spec(repo_spec)
                        if commit_id == ""
                                raise "unexpected lack of a commit ID"
                        end
                        Cspec.new(gr, commit_id, comment)
                end
                def is_repo_and_commit_id?(s)
                        # git;git.osn.oraclecorp.com;osn/serverintegration;master;aaaaaaaaaaaa
                        # type         ;  host   ; proj     ;brnch;commit_id
                        #   p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;121159
                        # type;host/port                    ;path;                                                               branch;rev
                        #  svn;adc4110308.us.oracle.com/scmadm@adc4110308.us.oracle.com/svn/idc/products/cs/branches/cloudtrunk-externalcompute/components-caas/CaaSServer/java;;158166
                        # type;host                    /path                                                                                                                   ;branch;rev
                        if Repo.parse_repo_and_possible_commit_id(s, false)
                                true
                        else
                                false
                        end
                end
                def grep_group1(commits, regexp)
                        raise "no regexp" unless regexp
                        group1_hits = []
                        commits.each do | commit |
                                if commit.comment
                                        z = commit.comment
                                else
                                        if commit.commit_id =~ /^\d+$/
                                                raise "comment not set (and commit_id is just a number, so not suitable for searching) for #{commit}"
                                        end
                                        z = commit.commit_id
                                end
                                if regexp.match(z)
                                        raise "no group 1 match for #{regexp}" unless $1
                                        group1_hits << $1
                                end
                        end
                        group1_hits
                end
                def list_files_changed_between(commit_spec1, commit_spec2)
                        # return Cspec_span_report_item listing the files changed between commit_spec1 and commit_spec2
                        commit1 = Cspec.from_repo_and_commit_id(commit_spec1)
                        commit2 = Cspec.from_repo_and_commit_id(commit_spec2)
                        return commit2.list_files_changed_since(commit1)
                end
                def test_list_changes_since()
                        compound_spec1 = "git;git.osn.oraclecorp.com;osn/serverintegration;;6b5ed0226109d443732540fee698d5d794618b64"
                        compound_spec2 = "git;git.osn.oraclecorp.com;osn/serverintegration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                        gc1 = Cspec.from_repo_and_commit_id(compound_spec1)
                        gc2 = Cspec.from_repo_and_commit_id(compound_spec2)
                        report_item1 = gc2.list_changes_since(gc1)
                        report_item2 = Cspec.list_changes_between(compound_spec1, compound_spec2)
                        changes1 = report_item1.item
                        changes2 = report_item2.item
                        U.assert_eq(changes1, changes2, "Cspec.test_list_changes_since - vfy same result from wrapper 0")

                        g1b = Cspec.from_repo_and_commit_id("git;git.osn.oraclecorp.com;osn/serverintegration;master;22ab587dd9741430c408df1f40dbacd56c657c3f")
                        g1a = Cspec.from_repo_and_commit_id("git;git.osn.oraclecorp.com;osn/serverintegration;master;7dfff5f400b3011ae2c4aafac286d408bce11504")

                        U.assert_array_to_s_eq([gc2, g1b, g1a], changes1, "test_list_changes_since")
                end
                def test_list_files_changed_since()
                        compound_spec1 = "git;git.osn.oraclecorp.com;osn/serverintegration;;6b5ed0226109d443732540fee698d5d794618b64"
                        compound_spec2 = "git;git.osn.oraclecorp.com;osn/serverintegration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                        gc1 = Cspec.from_repo_and_commit_id(compound_spec1)
                        gc2 = Cspec.from_repo_and_commit_id(compound_spec2)

                        report_item1 = gc2.list_files_changed_since(gc1)
                        report_item2 = Cspec.list_files_changed_between(compound_spec1, compound_spec2)
                        changed_files1 = report_item1.item
                        changed_files2 = report_item2.item
                        U.assert_eq(changed_files1, changed_files2, "vfy same result from wrapper 1")
                        U.assert_json_eq(["component.properties", "deps.gradle"], changed_files1, "Cspec.test_list_files_changed_since")
                end
                def test_json()
                        repo_spec = "git;git.osn.oraclecorp.com;osn/serverintegration;"
                        valentine_commit_id = "2bc0b1a58a9277e97037797efb93a2a94c9b6d99"
                        gc = Cspec.new(repo_spec, valentine_commit_id)
                        json = gc.to_json
                        U.assert_json_eq('{"repo_spec":"git;git.osn.oraclecorp.com;osn/serverintegration;","commit_id":"2bc0b1a58a9277e97037797efb93a2a94c9b6d99"}', json, 'Cspec.test_json')
                        gc2 = Cspec.from_s(json)
                        U.assert_eq(gc, gc2, "test ability to export to json, then import from that json back to the same object")
                end
                def test_list_bug_IDs_since()
                        # I noticed that for the commits in this range, there is a recurring automated comment "caas.build.pl.master/3013/" -- so
                        # I thought I would reset the pattern to treat that number like a bug ID for the purposes of the test.
                        # (At some point, i'll need to go find a comment that really does refer to a bug ID.)
                        saved_bug_id_regexp = Cspec_set.bug_id_regexp_val
                        begin
                                compound_spec1 = "git;git.osn.oraclecorp.com;osn/serverintegration;;6b5ed0226109d443732540fee698d5d794618b64"
                                compound_spec2 = "git;git.osn.oraclecorp.com;osn/serverintegration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"
                                gc1 = Cspec.from_repo_and_commit_id(compound_spec1)
                                gc2 = Cspec.from_repo_and_commit_id(compound_spec2)
                                Cspec_set.bug_id_regexp_val = Regexp.new(".*caas.build.pl.master/(\\d+)/.*", "m")
                                bug_IDs = gc2.list_bug_IDs_since(gc1)
                                U.assert_eq(["3013", "3012", "3011"], bug_IDs, "test_list_bug_IDs_since")

                                bug_IDs2_report_item_set = Cspec_set.list_bug_IDs_between(compound_spec1, compound_spec2)
                                bug_IDs2 = bug_IDs2_report_item_set.all_items
                                U.assert_eq(bug_IDs, bug_IDs2, "test_list_bug_IDs_between wrapper")
                        ensure
                                Cspec_set.bug_id_regexp_val = saved_bug_id_regexp
                        end
                end
                def test_is_repo_and_commit_id()
                        #U.assert_eq(true, Cspec.is_repo_and_commit_id?("svn;adc4110308.us.oracle.com;svn+ssh://adc4110308.us.oracle.com/svn/idc/products/cs;cloudtrunk-externalcompute;162615"),  "Cspec.is_repo_and_commit_id.9")
                        U.assert_eq(true, Cspec.is_repo_and_commit_id?("svn;adc4110308.us.oracle.com/svn/idc/products/cs;cloudtrunk-externalcompute;;162615"),  "Cspec.is_repo_and_commit_id.3")
                        U.assert_eq(true, Cspec.is_repo_and_commit_id?("git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed"), "Cspec.is_repo_and_commit_id")
                        U.assert_eq(true, Cspec.is_repo_and_commit_id?("git;git.osn.oraclecorp.com;osn/serverintegration;master;2bc0b1a58a9277e97037797efb93a2a94c9b6d99"), "Cspec.is_repo_and_commit_id 2")
                        U.assert_eq(true, Cspec.is_repo_and_commit_id?("ade;CTUNIT_TEST_GENERIC_180505.0743.0980"), "Cspec.is_repo_and_commit_id 3")
                        U.assert_eq(true, Cspec.is_repo_and_commit_id?("ade;CTUNIT_TEST_GENERIC_180505.0743.0980;abc"), "Cspec.is_repo_and_commit_id 4")
                        U.assert_eq(false, Cspec.is_repo_and_commit_id?("ade;CTUNIT_TEST_GENERIC_180505.0743.09809;abc"), "Cspec.is_repo_and_commit_id 5")
                        U.assert_eq(false, Cspec.is_repo_and_commit_id?("ade;CTUNIT_TEST_GENERIC_180505.07439.0980;abc"), "Cspec.is_repo_and_commit_id 6")
                        U.assert_eq(false, Cspec.is_repo_and_commit_id?("ade;CTUNIT_TEST_GENERIC_1805059.0743.0980;abc"), "Cspec.is_repo_and_commit_id 7")
                        U.assert_eq(false, Cspec.is_repo_and_commit_id?("ade;CTUNIT_TESTGENERIC_180505.0743.0980;abc"), "Cspec.is_repo_and_commit_id 8")
                end
                def test()
                        test_is_repo_and_commit_id()
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

class Cec_gradle_parser < Error_holder
        def initialize()

        end
        class << self
                attr_accessor :trace_autodiscovery

                def to_dep_commits(gradle_deps_text, gr)
                        dependency_commits = []
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
                                source_control_server = gr.source_control_server
                                if repo_parent.has_key?("git.repo.name")
                                        source_control_type = "git"
                                        git_project_basename = repo_parent["git.repo.name"][0] # e.g., caas.git
                                        branch_name = h["properties"][0]["git.repo.branch"][0]
                                        commit_id = h["properties"][0]["git.repo.commit.id"][0]
                                        if git_project_basename == "caas.git"
                                                project_name = "ccs/#{git_project_basename}"
                                        else
                                                project_name = "#{gr.get_project_name_prefix}/#{git_project_basename}"
                                        end
                                        project_name.sub!(/.git$/, '')
                                elsif repo_parent.has_key?("svn.repo.name")
                                        source_control_type = "svn"
                                        branch_name = h["properties"][0]["svn.repo.branch"][0]
                                        # example:
                                        # <properties>
                                        #    <svn.repo.name>adc4110308.us.oracle.com/svn/idc/products/cs</svn.repo.name>
                                        #    <svn.repo.branch>cloudtrunk-externalcompute</svn.repo.branch>
                                        #    <svn.repo.revision>159788</svn.repo.revision>
                                        #    <jenkins.build-url>https://osnci.us.oracle.com/job/docs.build.pl.master_external/638/</jenkins.build-url>
                                        #    <jenkins.build-id>638</jenkins.build-id>
                                        # </properties>
                                        repo_name = repo_parent["svn.repo.name"][0]
                                        if repo_name =~ /^([^\/]+)\/(.*)/
                                                source_control_server = $1
                                                project_name = $2
                                        else
                                                source_control_server = "svn.repo.name=#{repo_name}"
                                                project_name = "placeholder"
                                        end
                                        branch_name = repo_parent["svn.repo.branch"][0]
                                        commit_id = repo_parent["svn.repo.revision"][0]
                                        puts "repo_name=#{repo_name}, svn_branch=#{branch_name}, svn_commit_id=#{commit_id}" if trace_autodiscovery
                                else
                                        puts "not sure what this repo_parent is:"
                                        pp repo_parent
                                        next
                                end
                                repo_spec = Repo.make_spec(source_control_type, source_control_server, project_name, branch_name)
                                dependency_commit = Cspec.new(repo_spec, commit_id)
                                dependency_commits << dependency_commit
                                dependency_commits += dependency_commit.unreliable_autodiscovery_of_dependencies_from_build_configuration

                                puts "Cec_gradle_parser.to_dep_commits: dep project_name=#{project_name} (commit #{commit_id}), resolved to dep #{dependency_commit}" if trace_autodiscovery

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
                end
        end
end
