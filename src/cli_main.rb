require_relative 'u'
require_relative 'change_tracker'
require_relative 'json_change_tracker'

cms = Change_tracker_app.new

j = 0
while ARGV.size > j do
        arg = ARGV[j]
        case arg
        when "-test_clean"
                Git_repo.test_clean
        when "-compound_commit_json_of"
                puts Compound_commit.from_spec(ARGV[j+1]).to_json
                exit
        when "-conf"
                j += 1
                Global.data_json_fn = ARGV[j]
        when "-dry"
                U.dry_mode = true
        when "-list_bug_IDs_between"
                puts Compound_commit.list_bug_IDs_between(ARGV[j+1], ARGV[j+2])
                exit
        when "-list_changes_between"
                puts Compound_commit.list_changes_between(ARGV[j+1], ARGV[j+2])
                exit
        when "-list_changes_between_no_deps"
                Git_commit.list_changes_between(ARGV[j+1], ARGV[j+2])
                exit
        when "-list_files_changed_between"
                puts Compound_commit.list_files_changed_between(ARGV[j+1], ARGV[j+2])
                exit
        when "-list_files_changed_between_no_deps"
                puts Git_commit.list_files_changed_between(ARGV[j+1], ARGV[j+2])
                exit
        when "-test"
                U.test_mode = true
                Json_change_tracker.test
                Global.test
                Git_commit.test
                Git_repo.test
                Compound_commit.test
                Cec_gradle_parser.test
                exit
        when "-v"
                U.trace = true
        else
                if !cms.json_fn1
                        cms.json_fn1 = ARGV[j]
                elsif !cms.json_fn2
                        cms.json_fn2 = ARGV[j]
                else
                        raise "did not understand \"#{ARGV[j]}\""
                end
        end
        j += 1
end
cms.go