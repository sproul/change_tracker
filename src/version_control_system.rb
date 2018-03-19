class Version_control_system
        DEFAULT_BRANCH = "master"
        
        attr_accessor :repo
        def initialize(repo)
                self.repo = repo
        end
        def list_changes(commit1, commit2)
        end
        def latest_commit_id()
                self.repo.system("git log --pretty=format:'%H' -n 1")
        end
        def list_changed_files(commit_id)
                File_set.new(self.repo, self.repo.system_as_list("git diff-tree --no-commit-id --name-only -r #{commit_id}"))
        end
        def list_files()
                # https://stackoverflow.com/questions/8533202/list-files-in-local-git-repo
                self.repo.system_as_list("git ls-tree --full-tree -r HEAD --name-only")
        end
        def list_changes_since(commit1, commit2)
                change_lines = self.repo.system_as_list("git log --pretty=format:'%H %s' #{commit2.commit_id}..#{commit1.commit_id}")
                commits = []
                change_lines.map.each do | change_line |
                        self.raise "did not understand #{change_line}" unless change_line =~ /^([0-9a-f]+) (.*)$/
                        change_id, comment = $1, $2
                        commits << Cspec.from_repo_and_commit_id("#{repo.spec};#{change_id}", comment)
                end
                commits
        end
        def codeline_disk_write(root_dir, commit_id = nil)
                root_parent = File.dirname(root_dir)       # leave it to 'git clone' to make the root_dir itself
                FileUtils.mkdir_p(root_parent)

                username, pw = self.repo.get_credentials
                if !username
                        git_arg = "git@#{self.repo.source_control_server}:#{self.repo.project_name}.git"
                else
                        username_pw = "#{username}"
                        if pw != ""
                                username_pw << ":#{pw}"
                        end
                        git_arg = "https://#{username_pw}@#{self.repo.source_control_server}/#{self.repo.project_name}.git"
                end
                if self.repo.branch_name && self.repo.branch_name != DEFAULT_BRANCH
                        branch_arg = "-b \"#{self.repo.branch_name}\""
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
        def list_last_changes(n)
                self.repo..system_as_list("git log --oneline -n #{n} --pretty=format:'%H:%s'")
        end
        def get_file(path, commit_id)
                fn = "#{repo.codeline_disk_root}/#{path}"
                saved_file_by_commit = "#{fn}.___#{commit_id}"
                if !File.exist?(saved_file_by_commit)
                        cmd = "git show #{commit_id}:#{path} > #{saved_file_by_commit}"
                        begin
                                self.repo.system(cmd)
                        rescue
                                # I don't care why this failed, just return nil in this case
                                return nil
                        end
                end
                z = IO.read(saved_file_by_commit)
                if z==""
                        z = nil
                end
                z
        end
        def list_files_added_or_updated(commit_id)
                # https://stackoverflow.com/questions/424071/how-to-list-all-the-files-in-a-commit
                self.repo.system_as_list("git diff-tree --no-commit-id --name-only -r #{commit_id}")
        end
        class << self
        end
end
