class Version_control_system
        attr_accessor :repo
        def initialize(repo)
                self.repo = repo
        end
        def system_as_list(cmd, local_codeline_root_dir)
                U.system_as_list(cmd, nil, local_codeline_root_dir)
        end
        def system(cmd, local_codeline_root_dir)
                U.system(cmd, nil, local_codeline_root_dir)
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
class P4_version_control_system < Version_control_system
        attr_accessor :p4client
        attr_accessor :p4passwd
        attr_accessor :p4port
        attr_accessor :p4user
        attr_accessor :p4_path
        
        def initialize(repo)
                raise "bad repo spec #{repo}" unless repo =~ /p4;([\w\.:]+);/
                self.p4port = $1
                self.p4client = Global.get("#{self.p4port}.P4CLIENT")
                self.p4user =   Global.get("#{self.p4port}.P4USER")
                self.p4passwd = Global.get("#{self.p4port}.P4PASSWD")
                superclass.initialize(repo)
        end
        def list_changed_files(commit_id2)
                commit_id1 = self.repo.commit_id
                # exclude deletions (which are indicated by lines starting w/ "D"):
                File_set.new(self.repo, self.repo.system_as_list("p4 diff -r #{commit_id1}:#{commit_id2} --summarize").reject(/^D.*/))
        end
        def list_files()
                # https://stackoverflow.com/questions/14646798/how-to-list-all-files-in-a-remote-p4-repository
                return self.repo.system_as_list("p4 ls -R #{self.p4_path}")
        end
        def list_changes_since(commit1, commit2)
                return list_changes("#{commit2.commit_id}..#{commit1.commit_id}")
        end
        def list_changes(p4_changes_sh_arg_string)
                self.repo.system_as_list("p4_changes.sh #{p4_changes_sh_arg_string}").each do | change_line |
                        self.raise "did not understand #{change_line}" unless change_line =~ /^Change ([0-9]+) on \d\d\d\d.\d\d.\d\d by [\w@]+ (.*)$/
                        change_id, comment = $1, $2
                        commits << Cspec.from_repo_and_commit_id("#{repo.spec};#{change_id}", comment)
                end
                return commits
        end
        def codeline_disk_write(root_parent, root_dir, commit_id = nil)
                # probably can go w/out '-f', but I'm concerned about trouble since this is a new P4ROOT; p4 client has been confused about what is there before
                U.system("p4 sync -f \"#{self.p4_path}\"", nil, root_parent)
        end
        def list_last_changes(n)
                # https://www.perforce.com/perforce/r15.1/manuals/cmdref/p4_changes.html
                return list_changes("-m #{n} #{self.p4_path}")
        end
        def get_file(path, commit_id)
                fn = "#{repo.codeline_disk_root}/#{path}"
                saved_file_by_commit = "#{fn}.___#{commit_id}"
                if !File.exist?(saved_file_by_commit)
                        cmd = "p4 cat -r #{commit_id} #{path} > #{saved_file_by_commit}"
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
                File_set.new(self.repo, self.repo.system_as_list("p4 diff -r #{commit_id} --summarize").reject(/^D.*/))
        end
        def prepend_p4_var_settings(cmd)
                return "$SRC_ROOT/p4_wrapper.sh '#{self.p4client}' '#{self.p4user}' '#{self.p4passwd}' '#{self.p4port}' #{cmd}"
        end
        def system_as_list(cmd)
                superclass.system_as_list(prepend_p4_var_settings(cmd))
        end
        def system(cmd)
                superclass.system(        prepend_p4_var_settings(cmd))
        end
        class << self
                def test_list_changes_since()
                        compound_spec1 = "p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;121159"
                        compound_spec2 = "p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;129832"
                        cc1 = Cspec_set.from_repo_and_commit_id(compound_spec1)
                        cc2 = Cspec_set.from_repo_and_commit_id(compound_spec2)

                        gc2 = Cspec.from_repo_and_commit_id(compound_spec2)

                        changes = cc2.list_changes_since(cc1)
                        changes2 = Cspec_set.list_changes_between(compound_spec1, compound_spec2)
                        U.assert_eq(changes, changes2, "vfy same result from wrapper 2a")

                        g1b = Cspec.from_repo_and_commit_id("p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;121159")
                        g1a = Cspec.from_repo_and_commit_id("p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;129832")


                        U.assert_eq(gc2, changes[0], "test_list_changes_since.0")
                        U.assert_eq(g1b, changes[1], "test_list_changes_since.1")
                        U.assert_eq(g1a, changes[2], "test_list_changes_since.2")
                end
                def test_list_files_changed_since()
                        compound_spec1 = "p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;121159"
                        compound_spec2 = "p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;129832"
                        cc1 = Cspec_set.from_repo_and_commit_id(compound_spec1)
                        cc2 = Cspec_set.from_repo_and_commit_id(compound_spec2)

                        changed_files2 = Cspec_set.list_files_changed_between(compound_spec1, compound_spec2)
                        changed_files = cc2.list_files_changed_since(cc1)

                        U.assert_eq(changed_files, changed_files2, "vfy same result from wrapper 2b")

                        expected_changed_files = {
                        "git;git.osn.oraclecorp.com;osn/cec-server-integration;master" => [ "component.properties", "deps.gradle"],
                        "git;git.osn.oraclecorp.com;ccs/caas;master" => [ "component.properties", "deps.gradle"]
                        }

                        U.assert_json_eq(expected_changed_files, changed_files, "Cspec_set.test_list_files_changed_since")
                end
                def test_list_bug_IDs_since()
                        # I noticed that for the commits in this range, there is a recurring automated comment "caas.build.pl.master/3013/" -- so
                        # I thought I would reset the pattern to treat that number like a bug ID for the purposes of the test.
                        # (At some point, i'll need to go find a comment that really does refer to a bug ID.)
                        saved_bug_id_regexp = Cspec_set.bug_id_regexp_val
                        begin
                                compound_spec1 = "p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;121159"
                                compound_spec2 = "p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;129832"
                                gc1 = Cspec_set.from_repo_and_commit_id(compound_spec1)
                                gc2 = Cspec_set.from_repo_and_commit_id(compound_spec2)
                                Cspec_set.bug_id_regexp_val = Regexp.new(".*caas.build.pl.master/(\\d+)/.*", "m")
                                bug_IDs = gc2.list_bug_IDs_since(gc1)
                                U.assert_eq(["3013", "3012", "3011"], bug_IDs, "bug_IDs_since")
                        ensure
                                Cspec_set.bug_id_regexp_val = saved_bug_id_regexp
                        end
                end
                def test()
                        test_list_files_changed_since()
                        test_list_changes_since()
                        test_list_bug_IDs_since()
                end
        end
end
