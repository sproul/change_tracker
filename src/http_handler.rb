require 'sinatra'
require_relative 'json_change_tracker'

set :bind, '0.0.0.0'

get '/' do
        url = "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}#{request.env['QUERY_STRING']}"
        puts "here comes pp request..., url=#{url}"
        puts 
        pp request
        http_response_code, body = Json_change_tracker.new.go(params['json'])
        [ http_response_code, body ]
end
get '/exit' do
        Process.kill('TERM', Process.pid)
        # exit  # this leads to lots of warnings
end
