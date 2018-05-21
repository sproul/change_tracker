require_relative 'u'
require_relative 'change_tracker'
require_relative 'json_change_tracker'

def test()
        U.test_mode = true
        Json_change_tracker.init()
        #ADE_label.test()
        puts "SKIPPING ADE test"
        P4_version_control_system.test()
        Cspec_set.test
        Repo.test
        Cspec.test
        Svn_version_control_system.test()
        Json_change_tracker.test
        U.test
        Global.test
        Cec_gradle_parser.test
        puts "EOT"
        exit
end

STDOUT.sync = true      # otherwise some output can get lost if there is an exception or early exit
cms = Change_tracker_app.new

j = 0

U.init
while ARGV.size > j do
        arg = ARGV[j]
        case arg
        when "-1"
                U.raise_if_fail = true
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
                puts Cspec_set.list_bug_IDs_between(ARGV[j+1], ARGV[j+2]).to_json
                exit
        when "-list_bug_IDs_betweenf"
                puts Cspec_set.list_bug_IDs_between(IO.read(ARGV[j+1]), IO.read(ARGV[j+2])).to_json
                exit
        when "-list_changes_between"
                puts Cspec_set.list_changes_between(ARGV[j+1], ARGV[j+2]).to_json
                exit
        when "-list_changes_betweenf"
                puts Cspec_set.list_changes_between(IO.read(ARGV[j+1]), IO.read(ARGV[j+2])).to_json
                exit
        when "-list_changes_between_no_deps"
                Cspec.list_changes_between(ARGV[j+1], ARGV[j+2]).to_json
                exit
        when "-list_changes_between_no_depsf"
                Cspec.list_changes_between(IO.read(ARGV[j+1]), IO.read(ARGV[j+2])).to_json
                exit
        when "-list_files_changed_between"
                puts Cspec_set.list_files_changed_between(ARGV[j+1], ARGV[j+2]).to_json
                exit
        when "-list_files_changed_betweenf"
                puts Cspec_set.list_files_changed_between(IO.read(ARGV[j+1]), IO.read(ARGV[j+2])).to_json
                exit
        when "-list_files_changed_between_no_deps"
                puts Cspec.list_files_changed_between(ARGV[j+1], ARGV[j+2]).to_json
                exit
        when "-list_files_changed_between_no_depsf"
                puts Cspec.list_files_changed_between(IO.read(ARGV[j+1]), IO.read(ARGV[j+2])).to_json
                exit
        when "-list_last_changes"
                puts "["
                Cspec_set.list_last_changes(ARGV[j+1], ARGV[j+2].to_i).each do | cc |
                        puts cc.to_json
                end
                puts "]"
                exit
        when /(-oe|-output=expanded)/
                Cspec_span_report_item_set.output_style = Cspec_span_report_item::OUTPUT_STYLE_EXPANDED
                puts "Cspec_span_report_item_set.output_style=#{Cspec_span_report_item_set.output_style}"
        when /(-on|-output=normal)/
                Cspec_span_report_item_set.output_style = Cspec_span_report_item::OUTPUT_STYLE_NORMAL
                puts "Cspec_span_report_item_set.output_style=#{Cspec_span_report_item_set.output_style}"
        when /(-ot|-output)/
                Cspec_span_report_item_set.output_style = Cspec_span_report_item::OUTPUT_STYLE_TERSE
                puts "Cspec_span_report_item_set.output_style=#{Cspec_span_report_item_set.output_style}"
        when /(-p|-pretty)/
                Cspec_span_report_item_set.pretty = true
        when "-test"
                test()
        when "-tad"
                Cec_gradle_parser.trace_autodiscovery = true
        when "-trace_autodiscovery"
                Cec_gradle_parser.trace_autodiscovery = true
        when "-tcs"
                U.trace_calls_to_system = true
        when /(-tok|ok)/
                U.test_overwrite_canon_files_mode = true
                puts "Will overwrite test canon files, assuming that the current test behavior in the affected tests is correct..."
        when "-v"
                U.trace = true
                U.trace_calls_to_system = true
                U.trace_max(true)
                Cec_gradle_parser.trace_autodiscovery = true
        else
                if !cms.json_fn1
                        cms.json_fn1 = ARGV[j]
                        if !File.exist?(cms.json_fn1)
                                raise "could not find json file #{cms.json_fn1}"
                        end
                elsif !cms.json_fn2
                        cms.json_fn2 = ARGV[j]
                        if !File.exist?(cms.json_fn2)
                                raise "could not find json file #{cms.json_fn2}"
                        end
                else
                        raise "did not understand \"#{ARGV[j]}\""
                end
        end
        j += 1
end
cms.go
