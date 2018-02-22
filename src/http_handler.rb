require 'sinatra'

get '/' do
        'Supported operations:<br>...'
end

get '/list_bug_IDs_between' do
                compound_commit1 = Compound_commit.from_spec(ARGV[j])
                j += 1
                compound_commit2 = Compound_commit.from_spec(ARGV[j])
                compound_commit2.list_bug_IDs_since(compound_commit1).each do | bug_id |
                        puts bug_id
                end
                exit
                get '/-list_changes_between' do
                j += 1
                compound_commit1 = Compound_commit.from_spec(ARGV[j])
                j += 1
                compound_commit2 = Compound_commit.from_spec(ARGV[j])
                changes = compound_commit2.list_changes_since(compound_commit1)
                #puts Json_obj.array_of_json_to_s(changes, true)
                puts changes
                exit
                get '/list_changes_between_no_deps' do
                j += 1
                commit1 = Git_commit.from_spec(ARGV[j])
                j += 1
                commit2 = Git_commit.from_spec(ARGV[j])
                changes = commit2.list_changes_since(commit1)
                #puts Json_obj.array_of_json_to_s(changes, true)
                puts changes
                exit
                get '/list_changed_files_between' do
                j += 1
                compound_commit1 = Compound_commit.from_spec(ARGV[j])
                j += 1
                compound_commit2 = Compound_commit.from_spec(ARGV[j])
                changed_files = compound_commit2.list_changed_files_since(compound_commit1)
                #puts Json_obj.array_of_json_to_s(changed_files, true)
                puts changed_files
                exit
                get '/list_changed_files_between_no_deps' do
                j += 1
                commit1 = Git_commit.from_spec(ARGV[j])
                j += 1
                commit2 = Git_commit.from_spec(ARGV[j])
                changed_files = commit2.list_changed_files_since(commit1)
                #puts Json_obj.array_of_json_to_s(changed_files, true)
                puts changed_files
                exit

get '/exit' do
        Process.kill('TERM', Process.pid)
        # exit  # this leads to lots of warnings
end
