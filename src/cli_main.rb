require_relative 'u'
require_relative 'change_tracker'
require_relative 'json_change_tracker'

STDOUT.sync = true      # otherwise some output can get lost if there is an exception or early exit

cms = Change_tracker_app.new

j = 0
while ARGV.size > j do
        arg = ARGV[j]
        case arg
        when "-test_clean"
                Repo.test_clean
        when "-compound_commit_json_of"
                puts Cspec_set.from_repo_and_commit_id(ARGV[j+1]).to_json
                exit
        when "-conf"
                j += 1
                Global.data_json_fn = ARGV[j]
        when "-dry"
                U.dry_mode = true
        when "-list_bug_IDs_between"
                puts Cspec_set.list_bug_IDs_between(ARGV[j+1], ARGV[j+2])
                exit
        when "-list_changes_between"
                puts Cspec_set.list_changes_between(ARGV[j+1], ARGV[j+2])
                exit
        when "-list_changes_between_no_deps"
                Cspec.list_changes_between(ARGV[j+1], ARGV[j+2])
                exit
        when "-list_files_changed_between"
                puts Cspec_set.list_files_changed_between(ARGV[j+1], ARGV[j+2])
                exit
        when "-list_files_changed_between_no_deps"
                puts Cspec.list_files_changed_between(ARGV[j+1], ARGV[j+2])
                exit
        when "-list_last_changes"
                puts "["
                Cspec_set.list_last_changes(ARGV[j+1], ARGV[j+2].to_i).each do | cc |
                        puts cc.to_json
                end
                puts "]"
                exit
        when "-test"
                U.test_mode = true
                U.init
                Json_change_tracker.init()

                Cspec_set.test
                Json_change_tracker.test
                Cspec.test
                File_sets.test
                Global.test
                Repo.test
                Cec_gradle_parser.test
                puts "EOT"
                exit
        when "-tad"
                Cec_gradle_parser.trace_autodiscovery = true
        when "-trace_autodiscovery"
                Cec_gradle_parser.trace_autodiscovery = true
        when "-tcs"
                U.trace_calls_to_system = true
        when "-v"
                U.trace = true
                U.trace_calls_to_system = true
                Cec_gradle_parser.trace_autodiscovery = true
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
