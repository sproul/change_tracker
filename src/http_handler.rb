require 'sinatra'
require_relative 'json_change_tracker'

set :bind, '0.0.0.0'

get '/' do
        x = Json_change_tracker.go(params['json'])
        x.to_s
end
get '/exit' do
        Process.kill('TERM', Process.pid)
        # exit  # this leads to lots of warnings
end
