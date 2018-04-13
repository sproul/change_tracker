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

def log(s)
        puts 
end

def log_request()
        url = "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}#{request.env['QUERY_STRING']}"
end

get '/dump_globals' do
        headers['Content-Type'] = 'text/plain; charset=utf8'
        Global.dump_to_json
end

get '/note_renamed_repo' do
        from = params['from']
        if !from
                raise "from parm required"
        end
        to   = params['to']
        if !to
                raise "to parm required"
        end
        Repo.note_renamed_repo(from, to, true)
        headers['Content-Type'] = 'text/plain; charset=utf8'
        Global.dump_to_json
end

get '/note_renamed_branch' do
        from = params['from']
        if !from
                raise "from parm required"
        end
        to   = params['to']
        if !to
                raise "to parm required"
        end
        Repo.note_renamed_branch(from, to, true)
        headers['Content-Type'] = 'text/plain; charset=utf8'
        Global.dump_to_json
end

get '/' do
        if ! Json_change_tracker.initialized
                Json_change_tracker.init("#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}")
        end
        #log_request
        
        # 2018-03-08 09:54:46,803 [http-bio-8080-exec-19] DEBUG c.o.s.c.r.f.LoggingResponseFilter - Requesting GET for path v1/orchestrations/l2/integrations/asclassic:linux_x64:12.2.1.3.1/props
        # 2018-03-08 09:54:46,804 [http-bio-8080-exec-19] DEBUG c.o.s.c.r.f.LoggingResponseFilter - Response {

        
        
        
        #puts "here comes pp request..., url=#{url}"
        #pp request
        pretty = get_boolean(params['pretty'])
        op     = params['op']
        http_response_code, body = Json_change_tracker.new.go(op, params['cspec_set1'], params['cspec_set2'], pretty)
        if http_response_code == 200
                headers['Content-Type'] = 'text/plain; charset=utf8'
        else
                headers['Content-Type'] = 'text/html; charset=utf8'
        end
        [ http_response_code, body ]
end
get '/exit' do
        Process.kill('TERM', Process.pid)
        # exit  # this leads to lots of warnings
end
