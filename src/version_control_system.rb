class Version_control_system
        attr_accessor :repo
        def initialize(repo)
                self.repo = repo
        end
        class << self
                def from_repo(repo)
                        case repo.spec
                        when /git;.*/
                                Git_version_control_system.new(repo)
                        else
                                raise "unsupported repo type #{repo.spec}"
                        end
                end
        end
end
class Git_version_control_system < Version_control_system
        DEFAULT_BRANCH = "master"
        def latest_commit_id()
                return self.repo.system("git log --pretty=format:'%H' -n 1")
        end
        def list_changed_files(commit_id)
                File_set.new(self.repo, self.repo.system_as_list("git diff-tree --no-commit-id --name-only -r #{commit_id}"))
        end
        def list_files()
                # https://stackoverflow.com/questions/8533202/list-files-in-local-git-repo
                return self.repo.system_as_list("git ls-tree --full-tree -r HEAD --name-only")
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
        def codeline_disk_write(root_parent, root_dir, commit_id = nil)
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
                commits = []
                self.repo.system_as_list("git log --oneline -n #{n} --pretty=format:'%H:%s'").each do | id_colon_comment |
                        change_id = id_colon_comment.sub(/:.*/, '')
                        comment = id_colon_comment.sub(/.*?:/, '')
                        commits << Cspec.from_repo_and_commit_id("#{repo.spec};#{change_id}", comment)
                end
                commits
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
class Svn_version_control_system < Version_control_system
        DEFAULT_BRANCH = "trunk"
        attr_accessor :url
        def latest_commit_id()
                # https://stackoverflow.com/questions/579196/getting-the-last-revision-number-in-svn
                # svn info $url | grep 'Last Changed Rev' | awk '{ print $4; }'
                self.repo.system_as_list("svn info #{self.url}").grep(/Last Changed Rev/).split(/ /)[3]
        end
        def list_changed_files(commit_id2)
                commit_id1 = self.repo.commit_id
                # exclude deletions (which are indicated by lines starting w/ "D"):
                File_set.new(self.repo, self.repo.system_as_list("svn diff -r #{commit_id1}:#{commit_id2} --summarize").reject(/^D.*/))
        end
        def list_files()
                # https://stackoverflow.com/questions/14646798/how-to-list-all-files-in-a-remote-svn-repository
                return self.repo.system_as_list("svn ls -R #{self.url}")
        end
        def list_changes_since(commit1, commit2)
                change_lines = self.repo.system_as_list("svn log -r #{commit2.commit_id}:#{commit1.commit_id}")
                commits = []
                change_lines.map.each do | change_line |
                        self.raise "UNTESTED:::::: did not understand #{change_line}" unless change_line =~ /^([0-9a-f]+) (.*)$/
                        change_id, comment = $1, $2
                        commits << Cspec.from_repo_and_commit_id("#{repo.spec};#{change_id}", comment)
                end
                commits
        end
        def codeline_disk_write(root_parent, root_dir, commit_id = nil)
                #username, pw = self.repo.get_credentials
                #if !username
                #        git_arg = "git@#{self.repo.source_control_server}:#{self.repo.project_name}.git"
                #else
                #        username_pw = "#{username}"
                #        if pw != ""
                #                username_pw << ":#{pw}"
                #        end
                #        git_arg = "https://#{username_pw}@#{self.repo.source_control_server}/#{self.repo.project_name}.git"
                #end
                url = self.url
                if self.repo.branch_name && self.repo.branch_name != DEFAULT_BRANCH
                        url << "/branches/#{self.repo.branch_name}"
                else
                        url << "/trunk"
                end
                U.system("svn co \"#{url}\"", nil, root_parent)
        end
        def list_last_changes(n)
                # https://stackoverflow.com/questions/2675749/how-do-i-see-the-last-10-commits-in-reverse-chronoligical-order-with-svn
                commits = []
                self.repo.system_as_list("svn log --limit #{n}").each do | id_colon_comment |
                        raise "untested, figure out parsing for #{id_colon_comment}" unless id_colon_comment =~ /^\w+:.*$/
                        change_id = id_colon_comment.sub(/:.*/, '')
                        comment = id_colon_comment.sub(/.*?:/, '')
                        commits << Cspec.from_repo_and_commit_id("#{repo.spec};#{change_id}", comment)
                end
                commits
        end
        def get_file(path, commit_id)
                fn = "#{repo.codeline_disk_root}/#{path}"
                saved_file_by_commit = "#{fn}.___#{commit_id}"
                if !File.exist?(saved_file_by_commit)
                        cmd = "svn cat -r #{commit_id} #{path} > #{saved_file_by_commit}"
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
                # exclude deletions (which are indicated by lines starting w/ "D"):
                File_set.new(self.repo, self.repo.system_as_list("svn diff -r #{commit_id} --summarize").reject(/^D.*/))
        end
        class << self
        end
end
