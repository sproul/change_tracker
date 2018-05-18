require_relative 'version_control_system'

class Repo < Error_holder
        REPO_MV_DEFAULT = {}
        BRANCH_MV_DEFAULT = {}
        attr_accessor :branch_name
        attr_accessor :commit_id
        attr_accessor :global_data_prefix
        attr_accessor :project_name
        attr_accessor :source_control_server
        attr_accessor :source_control_type
        attr_accessor :vcs

        def spec()
                Repo.make_spec(self.source_control_type, self.source_control_server, self.project_name, branch_name)
        end
        def to_s()
                spec
        end
        def eql?(other)
                matching = self.source_control_server.eql?(other.source_control_server) &&
                self.source_control_type.eql?(other.source_control_type) &&
                self.project_name.eql?(other.project_name) &&
                self.branch_name.eql?(other.branch_name)
                return matching
        end
        def get(key, default_val=nil)
                Global.get(self.global_data_prefix + key, default_val)
        end
        def get_project_name_prefix()
                project_name.sub(/\/.*/, '')
        end
        def get_file(path, commit_id)
                return self.vcs.get_file(path, commit_id)
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
                "#{Repo.codeline_root_parent}/#{self.source_control_type}/#{self.source_control_server}/#{project_name}"
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
                        self.vcs.codeline_disk_write(root_parent, root_dir, commit_id)
                end
                self.commit_id = commit_id
                root_dir
        end
        def system_as_list(cmd)
                self.vcs.system_as_list(cmd)
        end
        def system(cmd)
                self.vcs.system(cmd)
        end
        class << self
                TEST_REPO_NAME = "git;git.osn.oraclecorp.com;osn/serverintegration"
                TEST_REPO_NAME_RENAMED = "git;git.osn.oraclecorp.com;osn/a_new_serverintegration_project.git"
                attr_accessor :codeline_root_parent
                attr_accessor :initialized
                attr_accessor :renamed_branches
                attr_accessor :renamed_repos

                def from_spec(repo_spec)
                        if !Repo.initialized
                                Repo.init
                        end
                        r = Repo.new
                        repo_spec = update_repo_spec_to_reflect_repo_moves(  repo_spec)
                        repo_spec = update_repo_spec_to_reflect_branch_moves(repo_spec)
                        # type         ;  host   ; proj     ;brnch              e.g.,
                        # git;git.osn.oraclecorp.com;osn/serverintegration;master

                        if repo_spec !~ /^(\w+);(.*)/
                                r.raise("did not see a source control type at the beginning of #{repo_spec}", 500)
                        end
                        r.source_control_type = $1
                        z = $2
                        # Note for p4, the host may include a colon + port (e.g., p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;)
                        if z !~ /^([-\w\.:]+);(.*)/
                                r.raise("did not see a host after type #{r.source_control_type} in #{repo_spec}", 500)
                        end
                        r.source_control_server = $1
                        z = $2

                        if z !~ /^([-\+@:\.\w\/]+);([-\w]*)$/
                                r.raise("cannot understand repo spec #{repo_spec} after type #{r.source_control_type} and server #{r.source_control_server} in #{z}", 500)
                        end
                        # git;git.osn.oraclecorp.com;osn/serverintegration;master
                        # type;  host               ; proj                     ;branch
                        project_name_path, r.branch_name = $1,$2
                        project_name = project_name_path.sub(/^\/*/, '')   # remove leading slashes so we can construct a reasonable dir path later
                        r.vcs = Version_control_system.from_repo(r)
                        if !r.branch_name || (r.branch_name == r.vcs.default_branch_name)
                                r.branch_name = ""
                        end
                        r.raise("empty project name") unless project_name && (project_name != "")
                        r.project_name = project_name.sub(/.git$/, '')
                        r.global_data_prefix = "#{r.source_control_type}_repo_#{project_name}."
                        if !Repo.codeline_root_parent
                                Repo.codeline_root_parent = Global.get_scratch_dir()
                        end
                        r.commit_id = nil
                        r
                end
                def init()
                        if !Repo.initialized
                                Repo.initialized = true
                                Repo.init_renamed_repos_hash
                                Repo.init_renamed_branches_hash
                        end
                end
                def init_renamed_repos_hash()
                        Repo.renamed_repos = Hash.new
                        Global.get("renamed_repos", REPO_MV_DEFAULT).each_pair do | from, to |
                                note_renamed_repo(from, to)
                        end
                end
                def init_renamed_branches_hash()
                        Repo.renamed_branches = Hash.new
                        Global.get("renamed_branches", BRANCH_MV_DEFAULT).each_pair do | from, to |
                                note_renamed_branch(from, to, false)
                        end
                end
                def parse_repo_and_possible_commit_id(z, throw_if_not=false)
                        original_parm = z
                        # type         ;  host   ; proj     ;brnch              e.g.,
                        # git;git.osn.oraclecorp.com;osn/serverintegration;master

                        if z !~ /^(\w+);(.*)/
                                if throw_if_not
                                        self.raise("did not see a source control type at the beginning of #{original_parm}", 500)
                                else
                                        return nil
                                end
                        end
                        source_control_type = $1
                        z = $2

                        # Note for p4, the host may include a colon + port (e.g., p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;)
                        if z !~ /^([-\w\.:]+);(.*)/
                                if throw_if_not
                                        self.raise("did not see a host after type #{source_control_type} in #{original_parm}", 500)
                                else
                                        return nil
                                end
                        end
                        source_control_server = $1
                        z = $2

                        if z !~ /^([-:@\+\.\w\/]+);(.*)/
                                if throw_if_not
                                        self.raise("did not see a project string after type #{source_control_type} and host #{source_control_server} in #{original_parm}", 500)
                                else
                                        return nil
                                end
                        end
                        project_name_path = $1
                        z = $2
                        project_name = project_name_path.sub(/^\/*/, '')   # remove leading slashes so we can construct a reasonable dir path later
                        if z && z =~ /(.*);(.*)/
                                branch_name, commit_id = $1, $2
                                return source_control_type, source_control_server, project_name, branch_name, commit_id
                        else
                                branch_name = z
                                return source_control_type, source_control_server, project_name, branch_name
                        end
                end
                def load_into_hash_a_regexp_anchored_to_boln_and_having_n_semicolon_delimited_components(h, before_string, n, after_string)
                        # this routine will load into hash 'h' a key-value pair where
                        # 1.) the key is a regular expression constructed from 'before_string'.  This regexp is anchored to the beginning of the line (i.e., is prefixed by '^'), and has 'n'
                        #     components delimited by ';' (e.g., the string 'a;b;c' has 3 components delimited by semicolons).
                        # 2.) the value is 'after_string'
                        components = before_string.split(/;/)
                        if components.size != n
                                raise "expected #{n} semicolon-delimited components in #{before_string} (but saw #{components.size} components instead)"
                        end
                        # following the 'before_string' we have a zero-width lookahead so we match the case where nothing follows the matching string OR what follows is ;.*
                        #       Trouble is that this doesn't work, due to the $ anchor at the end.  I think this is a zero-width assertion bug?  -nas
                        # before_regexp = Regexp.new("^#{before_string}(?=(;.*)?)$")
                        # h[before_regexp] = after_string
                        
                        before_regexp = Regexp.new("^#{before_string}(;.*)?$")
                        h[before_regexp] = "#{after_string}\\1"
                end
                def load_hash_of_regexps_having_n_semicolon_delimited_components_from_string_hash(string_h, n)
                        # this routine takes a string hash 'string_h' as input and creates a new hash whose keys are equivalent Regexp objects.
                        # Along the way, this routine verifies that the string keys have 'n' semicolon-delimited components
                        regexp_h = Hash.new
                        string_h.each_pair do | string_key, string_val |

                        end
                        regexp_h
                end
                def note_renamed_repo(from, to, persist=false)
                        Repo.init
                        # e.g., git;git.osn.oraclecorp.com;osn/cec-server-integration becomes git;git.osn.oraclecorp.com;osn/serverintegration
                        #       111 2222222222222222222222 33333333333333333333333333
                        load_into_hash_a_regexp_anchored_to_boln_and_having_n_semicolon_delimited_components(Repo.renamed_repos, from, 3, to)
                        if persist
                                Global.init_data

                                Global.data.h["renamed_repos"] = Hash.new if !Global.data.h.has_key?("renamed_repos")

                                Global.data.h["renamed_repos"][from] = to
                                Global.save
                        end
                end
                def note_renamed_branch(from, to, persist=false)
                        Repo.init
                        # e.g., git;git.osn.oraclecorp.com;osn/serverintegration;master becomes git;git.osn.oraclecorp.com;osn/serverintegration;master_external
                        #       111 2222222222222222222222 333333333333333333333 444444
                        load_into_hash_a_regexp_anchored_to_boln_and_having_n_semicolon_delimited_components(Repo.renamed_branches, from, 4, to)
                        if persist
                                Global.init_data

                                Global.data.h["renamed_branches"] = Hash.new if !Global.data.h.has_key?("renamed_branches")

                                Global.data.h["renamed_branches"][from] = to
                                Global.save
                        end
                end
                def make_spec(vcs_type, source_control_server, repo_name, branch)
                        self.raise "bad source_control_server #{source_control_server} (from make_spec(vcs_type=#{vcs_type}, source_control_server=#{source_control_server}, repo_name=#{repo_name}, branch=#{branch}" unless source_control_server && source_control_server.is_a?(String) && source_control_server != ""
                        self.raise "bad repo_name #{repo_name}" unless repo_name && repo_name.is_a?(String) && repo_name != ""
                        if !branch
                                branch = ""
                        end
                        "#{vcs_type};#{source_control_server};#{repo_name};#{branch}"
                end
                def test_clean()
                        gr = Repo.from_spec(TEST_REPO_NAME)
                        gr.codeline_disk_remove
                        U.assert(!gr.codeline_disk_exist?)
                end
                def test_repo_renaming()
                        Repo.note_renamed_repo("git;git.osn.oraclecorp.com;osn/cec-server-integration", "git;git.osn.oraclecorp.com;osn/serverintegration")

                        updated = Repo.from_spec("git;git.osn.oraclecorp.com;osn/cec-server-integration;")
                        U.assert_eq(             "git;git.osn.oraclecorp.com;osn/serverintegration;", updated.spec, "test_repo_renaming.0")

                        updated = Repo.from_spec("git;git.osn.oraclecorp.com;osn/cec-server-integration;XYZ")
                        U.assert_eq(             "git;git.osn.oraclecorp.com;osn/serverintegration;XYZ", updated.spec, "test_repo_renaming.1")
                end
                def test()
                        test_repo_renaming()
                        gr = Repo.from_spec("#{TEST_REPO_NAME};")
                        gr2 = Repo.from_spec("#{TEST_REPO_NAME}.git;")
                        U.assert_eq(gr, gr2, "testing that specifying .git is ok")
                        gr2 = Repo.from_spec("#{TEST_REPO_NAME}.git;master")
                        U.assert_eq(gr, gr2, "unspecified branch should match master")
                        gr3 = Repo.from_spec("#{TEST_REPO_NAME_RENAMED};")
                        U.assert_ne(gr, gr3, "testing that different branch means not eql")
                        Repo.note_renamed_branch("#{TEST_REPO_NAME};branch_abc", "#{TEST_REPO_NAME};branch_xyz")
                        gr  = Repo.from_spec("#{TEST_REPO_NAME};branch_abc")      # reinitialize to get the benefit of the note_renamed_branch call
                        gr2 = Repo.from_spec("#{TEST_REPO_NAME};branch_xyz")      # reinitialize to get the benefit of the note_renamed_branch call
                        U.assert_eq(gr, gr2, "branch renaming w/ both explicit")
                        #
                        # branch rename of the default branch is pobably a pathological case -- ignore for now.
                        #gr = Repo.from_spec("#{TEST_REPO_NAME};")
                        # U.assert_eq(gr, gr2, "testing that renaming branch works even w/ implicit branch")
                        
                        gr.codeline_disk_write
                        U.assert(gr.codeline_disk_exist?)
                        deps_gradle_content = gr.get_file("deps.gradle", "2bc0b1a58a9277e97037797efb93a2a94c9b6d99")
                        U.assert(deps_gradle_content, "deps_gradle_content.get_file non-nil")
                        U.assert(deps_gradle_content != "", "deps_gradle_content.get_file not empty")
                        manifest_lines = deps_gradle_content.split("\n").grep(/manifest/)
                        U.assert(manifest_lines.size > 1, "deps_gradle_content.manifest_lines_gt_1")
                end
                def update_repo_spec_to_reflect_repo_moves(repo_spec)
                        repo_spec_original = repo_spec
                        Repo.renamed_repos.keys.each do | before_regexp |
                                after = Repo.renamed_repos[before_regexp]
                                repo_spec = repo_spec.sub(before_regexp, after)
                                puts "update_repo_spec_to_reflect_repo_moves #{before_regexp} to #{after}: #{repo_spec}" if U.trace
                        end
                        if repo_spec != repo_spec_original && U.trace
                                puts "update_repo_spec_to_reflect_repo_moves: #{repo_spec_original} -> #{repo_spec}"
                        end
                        return repo_spec
                end
                def update_repo_spec_to_reflect_branch_moves(repo_spec)
                        repo_spec_original = repo_spec
                        Repo.renamed_branches.keys.each do | before_regexp |
                                after = Repo.renamed_branches[before_regexp]
                                repo_spec = repo_spec.sub(before_regexp, after)
                        end
                        if repo_spec != repo_spec_original && U.trace
                                puts "update_repo_spec_to_reflect_branch_moves: #{repo_spec_original} -> #{repo_spec}"
                        end
                        return repo_spec
                end
        end
end
