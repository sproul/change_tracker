require_relative 'version_control_system'

class Repo < Error_holder
        attr_accessor :branch_name
        attr_accessor :change_tracker_host_and_port
        attr_accessor :global_data_prefix
        attr_accessor :project_name
        attr_accessor :source_control_server
        attr_accessor :source_control_type
        attr_accessor :vcs

        def initialize(repo_spec, change_tracker_host_and_port = nil)
                self.change_tracker_host_and_port = change_tracker_host_and_port
                # type         ;  host   ; proj     ;brnch
                if repo_spec !~ /^(\w+);([-\w\.]+);([-\.\w\/]+);(\w*)$/
                        self.raise("cannot understand repo spec #{repo_spec}", 500)
                end
                # git;git.osn.oraclecorp.com;osn/cec-server-integration;master
                # type;  host               ; proj                     ;branch
                self.source_control_type, self.source_control_server, self.project_name, self.branch_name = $1,$2,$3,$4
                if source_control_type != "git"
                        self.raise("unexpected source_control_type #{source_control_type} from #{repo_spec}", 501)
                end
                self.source_control_type = source_control_type
                if !branch_name || branch_name == ""
                        self.branch_name = Git_version_control_system::DEFAULT_BRANCH
                else
                        self.branch_name = branch_name
                end
                self.raise("empty project name") unless project_name && (project_name != "")
                self.project_name = project_name
                self.global_data_prefix = "git_repo_#{project_name}."
                self.source_control_server = source_control_server
                if !Repo.codeline_root_parent
                        Repo.codeline_root_parent = Global.get_scratch_dir("git")
                end
                self.vcs = Version_control_system.from_repo(self)
        end
        def spec()
                Repo.make_spec(source_control_server, project_name, branch_name, change_tracker_host_and_port)
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
                "#{Repo.codeline_root_parent}/#{self.source_control_server}/#{project_name}"
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
                root_dir
        end
        def system_as_list(cmd)
                local_codeline_root_dir = self.codeline_disk_write
                self.raise "no codeline for #{self}" unless local_codeline_root_dir
                self.vcs.system_as_list(cmd, local_codeline_root_dir)
        end
        def system(cmd)
                local_codeline_root_dir = self.codeline_disk_write
                self.raise "no codeline for #{self}" unless local_codeline_root_dir
                self.vcs.system(cmd, local_codeline_root_dir)
        end
        class << self
                TEST_REPO_NAME = "git;git.osn.oraclecorp.com;osn/cec-server-integration;"
                attr_accessor :codeline_root_parent
                def make_spec(source_control_server, repo_name, branch=Git_version_control_system.DEFAULT_BRANCH, change_tracker_host_and_port=nil)
                        source_control_type = "git"
                        self.raise "bad source_control_server #{source_control_server}" unless source_control_server && source_control_server.is_a?(String) && source_control_server != ""
                        self.raise "bad repo_name #{repo_name}" unless repo_name && repo_name.is_a?(String) && repo_name != ""
                        branch = "" unless branch
                        change_tracker_host_and_port = "" unless change_tracker_host_and_port
                        "#{source_control_type};#{source_control_server};#{repo_name};#{branch}"        #       ;#{change_tracker_host_and_port}"
                end
                def test_clean()
                        gr = Repo.new(TEST_REPO_NAME)
                        gr.codeline_disk_remove
                        U.assert(!gr.codeline_disk_exist?)
                end
                def test()
                        gr = Repo.new(TEST_REPO_NAME)
                        gr.codeline_disk_write
                        U.assert(gr.codeline_disk_exist?)
                        deps_gradle_content = gr.get_file("deps.gradle", "2bc0b1a58a9277e97037797efb93a2a94c9b6d99")
                        U.assert(deps_gradle_content, "deps_gradle_content.get_file non-nil")
                        U.assert(deps_gradle_content != "", "deps_gradle_content.get_file not empty")
                        manifest_lines = deps_gradle_content.split("\n").grep(/manifest/)
                        U.assert(manifest_lines.size > 1, "deps_gradle_content.manifest_lines_gt_1")
                end
        end
end
