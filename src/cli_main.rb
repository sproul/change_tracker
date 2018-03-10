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
                puts JSON.pretty_generate(Cspec_set.from_spec(ARGV[j+1]))
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
                Git_cspec.list_changes_between(ARGV[j+1], ARGV[j+2])
                exit
        when "-list_files_changed_between"
                puts Cspec_set.list_files_changed_between(ARGV[j+1], ARGV[j+2])
                exit
        when "-list_files_changed_between_no_deps"
                puts Git_cspec.list_files_changed_between(ARGV[j+1], ARGV[j+2])
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
                Json_change_tracker.test
                File_sets.test
                Cspec_set.test
                Git_cspec.test
                Global.test
                Git_repo.test
                Cec_gradle_parser.test
                puts "EOT"
                exit
        when "-trace_autodiscovery"
                Cec_gradle_parser.trace_autodiscovery = true
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
