class Version_control_system
        attr_accessor :repo
        attr_accessor :type
        def initialize(repo)
                if !self.type
                        raise "I expect vcs-specific initialize to run first, setting the type field, but that appears not to have happened here?"
                end
                self.repo = repo
        end
        def list_changes_since(commit1, commit2)
                Cspec_span_report_item.new(commit1, commit2, self.get_changes_array_since(commit1, commit2))
        end
        def system_as_list(cmd)
                local_codeline_root_dir = self.repo.codeline_disk_write
                self.raise "no codeline for #{self}" unless local_codeline_root_dir
                U.system_as_list(cmd, nil, local_codeline_root_dir)
        end
        def system(cmd)
                local_codeline_root_dir = self.repo.codeline_disk_write
                self.raise "no codeline for #{self}" unless local_codeline_root_dir
                U.system(cmd, nil, local_codeline_root_dir)
        end
        class << self
                def from_repo(repo)
                        case repo.source_control_type
                        when "git"
                                Git_version_control_system.new(repo)
                        when "p4"
                                P4_version_control_system.new(repo)
                        when "svn"
                                Svn_version_control_system.new(repo)
                        else
                                raise "unsupported repo type #{repo.spec}"
                        end
                end
        end
end
class Git_version_control_system < Version_control_system
        DEFAULT_BRANCH = "master"
        def initialize(repo)
                self.type = "git"
                super
        end
        def get_changed_files_array(commit_id)
                self.system_as_list("git diff-tree --no-commit-id --name-only -r #{commit_id}")
        end
        def list_files(commit_id)
                # https://stackoverflow.com/questions/8533202/list-files-in-local-git-repo
                return self.system_as_list("git ls-tree --full-tree -r #{commit_id} --name-only")
        end
        def get_changes_array_since(commit1, commit2)
                change_lines = self.system_as_list("git log --pretty=format:'%H %s' #{commit2.commit_id}..#{commit1.commit_id}")
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
                self.system_as_list("git log --oneline -n #{n} --pretty=format:'%H:%s'").each do | id_colon_comment |
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
                                self.system(cmd)
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
                self.system_as_list("git diff-tree --no-commit-id --name-only -r #{commit_id}")
        end
        class << self
        end
end
class Svn_version_control_system < Version_control_system
        DEFAULT_BRANCH = "trunk"
        attr_accessor :url
        def initialize(repo)
                self.type = "svn"
                super
        end
        def get_changed_files_array(commit_id)
                previous_commit_id = self.repo.commit_id.to_i - 1
                # exclude deletions (which are indicated by lines starting w/ "D"):
                self.system_as_list("svn diff -r --summarize -r#{previous_commit_id}:#{commit_id}").reject(/^D.*/)
        end
        def list_files(commit_id)
                # https://stackoverflow.com/questions/14646798/how-to-list-all-files-in-a-remote-svn-repository
                return self.system_as_list("svn ls -R #{self.url}@#{commit_id}")
        end
        def get_changes_array_since(commit1, commit2)
                change_lines = self.system_as_list("svn log -r #{commit2.commit_id}:#{commit1.commit_id}")
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
                self.system_as_list("svn log --limit #{n}").each do | id_colon_comment |
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
                                self.system(cmd)
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
                self.system_as_list("svn diff -r #{commit_id} --summarize").reject(/^D.*/)
        end
        class << self
        end
end
class P4_version_control_system < Version_control_system
        attr_accessor :p4client
        attr_accessor :p4passwd
        attr_accessor :p4user
        attr_accessor :p4_path
        
        def initialize(repo)
                self.type = "p4"
                self.p4_path = "//#{repo.project_name}"
                self.p4client = Global.get("#{repo.source_control_server}.P4CLIENT")
                self.p4user =   Global.get("#{repo.source_control_server}.P4USER")
                self.p4passwd = Global.get("#{repo.source_control_server}.P4PASSWD")
                super
        end
        def list_files_added_or_updated(commit_id)
                # example:
                # % p4 describe -s 121159
                # Change 121159 by TimL@lake2 on 2003/12/17 17:40:45
                # 
                # Rename //IP/transformPortlet/main/... To //PT/portal/main/transformPortlet/...
                # 
                # Affected files ...
                # 
                # ... //IP/transformPortlet/main/.classpath#12 delete
                # ... //PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities/resources/Resource_pt.properties#1 branch
                # ... //PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities/resources/Resource_zh.properties#1 branch
                # 
                changed_files = []
                system_as_list("p4 describe -s #{commit_id}").each do | describe_output_line |
                        if describe_output_line =~ /^\.\.\. (\/\/.*)#\d+ (\w+)$/
                                fn, operation = $1, $2
                                if operation != "delete"
                                        changed_files << fn
                                end
                        end
                end
                changed_files
        end
        def get_changed_files_array(commit_id)
                list_files_added_or_updated(commit_id)
        end
        def list_files(commit_id)
                return system_as_list("p4 files #{self.p4_path}@#{commit_id}")
        end
        def get_changes_array_since(commit1, commit2)
                # nice discussion of changeset ranges in p4:
                # https://stackoverflow.com/questions/14646798/how-to-list-all-files-in-a-remote-p4-repository
                
                if commit2.commit_id < commit1.commit_id
                        z = commit1
                        commit1 = commit2
                        commit2 = z
                end
                return list_changes("#{self.p4_path}/...@#{commit1.commit_id},#{commit2.commit_id}")
        end
        def list_changes(p4_changes_sh_arg_string)
                commits = []
                self.system_as_list("p4_changes.sh #{p4_changes_sh_arg_string}").each do | change_line |
                        if change_line !~ /^Change ([0-9]+) on \d\d\d\d.\d\d.\d\d by [\w@]+ (.*)$/
                                self.raise "did not understand #{change_line}"
                        end
                        change_id, comment = $1, $2
                        commits << Cspec.from_repo_and_commit_id("#{repo.spec};#{change_id}", comment)
                end
                return commits.reverse
        end
        def codeline_disk_write(root_parent, root_dir, commit_id = nil)
                # probably can go w/out '-f', but I'm concerned about trouble since this is a new P4ROOT; p4 client has been confused about what is there before
                cmd = "p4 sync -f \"#{self.p4_path}/...\""
                puts "cmd=#{cmd}"
                out = U.system(cmd, nil, root_parent)
                raise "could not find #{root_dir} (#{out})" unless Dir.exist?(root_dir)
                return root_dir
        end
        def list_last_changes(n)
                # https://www.perforce.com/perforce/r15.1/manuals/cmdref/p4_changes.html
                return list_changes("-m #{n} #{self.p4_path}")
        end
        def get_file(path, commit_id)
                fn = "#{repo.codeline_disk_root}/#{path}"
                saved_file_by_commit = "#{fn}.___#{commit_id}"
                if !File.exist?(saved_file_by_commit)
                        begin
                                cmd = "p4 print #{self.p4_path}#{path}@#{commit_id} > #{saved_file_by_commit}"
                                return system(cmd)
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
        def prepend_p4_var_settings(cmd)
                augmented_cmd = "p4_wrapper.sh '#{self.p4client}' '#{self.p4user}' '#{self.p4passwd}' '#{self.repo.codeline_disk_root()}' '#{self.repo.source_control_server}' #{cmd}"
                return augmented_cmd
        end
        def system_as_list(cmd)
                super(prepend_p4_var_settings(cmd))
        end
        def system(cmd)
                superclass.system(        prepend_p4_var_settings(cmd))
        end
        class << self
                def test_p4_list_changes_since()
                        compound_spec1 = "p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;121159"
                        compound_spec2 = "p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;129832"
                        cc1 = Cspec_set.from_repo_and_commit_id(compound_spec1)
                        cc2 = Cspec_set.from_repo_and_commit_id(compound_spec2)

                        gc2 = Cspec.from_repo_and_commit_id(compound_spec2)

                        report_item_set1 = cc2.list_changes_since(cc1)
                        report_item_set2 = Cspec_set.list_changes_between(compound_spec1, compound_spec2)
                        changes1 = report_item_set1.all_items
                        changes2 = report_item_set2.all_items
                        U.assert_eq(changes1, changes2, "p4 vfy same result from wrapper 2a")

                        g1b = Cspec.from_repo_and_commit_id(compound_spec1)
                        g1a = Cspec.from_repo_and_commit_id(compound_spec2)

                        U.assert_eq(gc2, changes1[3], "test_p4_list_changes_since.0")
                        U.assert_eq(g1b, changes1[0], "test_p4_list_changes_since.1")
                        U.assert_eq(g1a, changes1[3], "test_p4_list_changes_since.2")
                end
                def test_p4_list_files_changed_since()
                        compound_spec1 = "p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;121159"
                        compound_spec2 = "p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;129832"
                        cc1 = Cspec_set.from_repo_and_commit_id(compound_spec1)
                        cc2 = Cspec_set.from_repo_and_commit_id(compound_spec2)

                        report_item_set1 = Cspec_set.list_files_changed_between(compound_spec1, compound_spec2)
                        report_item_set2 = cc2.list_files_changed_since(cc1)
                        changed_files1 = report_item_set1.all_items
                        changed_files2 = report_item_set2.all_items

                        U.assert_eq(changed_files1, changed_files2, "vfy same result from wrapper p4.2b")
                        U.assert_json_eq_f(changed_files1, "test_p4_list_files_changed_since")
                end
                def test_p4_list_bug_IDs_since()
                        # I noticed that for the commits in this range, there is a recurring automated comment "caas.build.pl.master/3013/" -- so
                        # I thought I would reset the pattern to treat that number like a bug ID for the purposes of the test.
                        # (At some point, i'll need to go find a comment that really does refer to a bug ID.)
                        saved_bug_id_regexp = Cspec_set.bug_id_regexp_val
                        begin
                                compound_spec1 = "p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;121159"
                                compound_spec2 = "p4;p4plumtree.us.oracle.com:1666;//PT/portal/main/transformPortlet/src/com/plumtree/transform/utilities;;129832"
                                gc1 = Cspec_set.from_repo_and_commit_id(compound_spec1)
                                gc2 = Cspec_set.from_repo_and_commit_id(compound_spec2)
                                Cspec_set.bug_id_regexp_val = Regexp.new("Update by (\\w+).*", "m")
                                report_item_set = gc2.list_bug_IDs_since(gc1)
                                bug_IDs = report_item_set.all_items
                                U.assert_eq(["EW", "SDL"], bug_IDs, "p4_bug_IDs_since")
                        ensure
                                Cspec_set.bug_id_regexp_val = saved_bug_id_regexp
                        end
                end
                def test()
                        test_p4_list_changes_since()
                        test_p4_list_files_changed_since()
                        test_p4_list_bug_IDs_since()
                end
        end
end
