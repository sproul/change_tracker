require 'cgi'

host, = ARGV
if !host
        host = "slcipcn.us.oracle.com"
end

url = "http://#{host}:4567?"
name = nil
val = nil
STDIN.readlines.each do | line |
        line.chomp!
        case line
        when /^\S.*=.+/
                url << line << "&"
        when /^}/
                val << line
                url << name << "=" << CGI::escape(val) << "&"
                name = nil
                val = nil
        else
                if !name
                        name = line
                        val = ''
                else
                        val << line
                end 
        end
end
url << "unused=unused"
cmd = "curl --silent '#{url}'"
puts cmd
puts `#{cmd}`
