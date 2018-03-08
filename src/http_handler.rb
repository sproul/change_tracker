require 'sinatra'
require_relative 'json_change_tracker'

set :bind, '0.0.0.0'

def get_boolean(val_from_url_parm)
        if !val_from_url_parm
                return "false"
        end
        if val_from_url_parm =~ /^(true|yes|t|y)$/i
                return "true"
        end
        if val_from_url_parm =~ /^(false|no|f|n)$/i
                return "false"
        end
        raise RuntimeError.new("did not recognize boolean parameter #{val_from_url_parm}")
end

get '/' do
        url = "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}#{request.env['QUERY_STRING']}"
        puts "here comes pp request..., url=#{url}"
        puts 
        pp request
        pretty = get_boolean(params['pretty'])
        puts "pretty=#{pretty}"
        http_response_code, body = Json_change_tracker.new.go(params['json'], pretty, headers)
        [ http_response_code, body ]
end
get '/exit' do
        Process.kill('TERM', Process.pid)
        # exit  # this leads to lots of warnings
end
