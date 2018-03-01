require 'sinatra'
require_relative 'json_change_tracker'

set :bind, '0.0.0.0'

get '/' do
        http_response_code, body = Json_change_tracker.new.go(params['json'])
        [ http_response_code, body ]
end
get '/exit' do
        Process.kill('TERM', Process.pid)
        # exit  # this leads to lots of warnings
end
