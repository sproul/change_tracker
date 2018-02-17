require 'rubygems'
require 'pp'
require 'open3'
require 'time'
require 'net/http'
require 'json'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

class SortedArray < Array
        attr_accessor :inverted
        
        def reverse_automatic_sorting()
                self.inverted = true
                self.sort{|a,b| b<=>a }
        end
        def self.[] *array
                SortedArray.new(array)
        end

        def initialize array=nil
                super( array.sort ) if array
        end

        def << value
                insert index_of_last_LE(value), value
        end

        alias push <<
        alias shift <<

        def index_of_last_LE value
                l,r = 0, length-1
                while l <= r
                        m = (r+l) / 2
                        #puts "{l}({self[l]})--{m}({self[m]})--{r}({self[r]})"
                        cmp_val = (value <=> self[m])
                        if (!self.inverted && cmp_val > 0) || (self.inverted && cmp_val <= 0)
                                r = m - 1
                        else
                                l = m + 1
                        end
                end
                #puts "Answer: {l}:({self[l]})"
                l
        end
end

class Pfr_counter
        attr_accessor :name
        attr_accessor :n
        attr_accessor :_total_time
        attr_accessor :avg_time
        def initialize(name, time_elapsed)
                self.name = name
                self.n = 1
                self._total_time = self.avg_time = time_elapsed
                if !Pfr_counter.name_to_counter
                        Pfr_counter.name_to_counter = Hash.new
                end
                Pfr_counter.name_to_counter[name] = self
        end
        def hit(time_elapsed)
                self.n += 1
                self._total_time += time_elapsed.to_i
                self.avg_time = self._total_time.to_f / self.n
                #raise "unexpected zero from #{self._total_time}/#{self.n}" if self.avg_time == 0
        end
        def <=>(other)
                val = (other.avg_time <=> self.avg_time)
                #puts "#{self}<=>(#{other} is #{val}"
                val
        end
        def to_s()
                "Pfr_c/#{self.avg_time}"
        end
        class << self
                attr_accessor :name_to_counter
                def find(name)
                        if !Pfr_counter.name_to_counter
                                Pfr_counter.name_to_counter = Hash.new
                        end
                        Pfr_counter.name_to_counter[name]
                end
        end
end

class Pfr_counter_group
        attr_accessor :inverted
        attr_accessor :maximum_count_of_items_to_track
        attr_accessor :maximum_count_of_items_to_report
        attr_accessor :counters
        attr_accessor :minimum_avg_to_track
        def initialize(maximum_count_of_items_to_track, maximum_count_of_items_to_report, inverted=false)
                self.inverted = inverted
                raise "number of items reported must be < items tracked, hello!" unless maximum_count_of_items_to_report < maximum_count_of_items_to_track
                self.maximum_count_of_items_to_report = maximum_count_of_items_to_report
                self.maximum_count_of_items_to_track = maximum_count_of_items_to_track
        end
        def hit(name, time_elapsed)
                time_elapsed = time_elapsed.to_i
                if !self.counters
                        self.counters = SortedArray.new
                        self.counters.reverse_automatic_sorting
                        self.minimum_avg_to_track = 0
                end
                z = Pfr_counter.find(name)
                if z
                        z.hit(time_elapsed)
                else
                        if time_elapsed < self.minimum_avg_to_track
                                # ignore this fast event
                                return
                        end
                        z = Pfr_counter.new(name, time_elapsed)
                        self.counters << z
                        if self.counters.size > self.maximum_count_of_items_to_track
                                self.counters.pop
                                self.minimum_avg_to_track = self.counters.last.avg_time
                        end
                end
        end
        def report(column_header)
                slowest_counters = self.counters[0..self.maximum_count_of_items_to_report]
                numeric_column_header = "avg resp time"
                puts sprintf "%14s %12s %s", numeric_column_header, "cnt", column_header
                puts "-------------- ------------ --------------"
                slowest_counters.each do | counter |
                        puts sprintf "%14d %8s %s", counter.avg_time, counter.n, counter.name
                end
        end
end


class Test_assertion < Exception
end


# like Hash but each val is an array of unique vals
class Hash_of_arrays < Hash
        def delete_val(key, val)
                ar = self[key]
                if val
                        ar.delete(val)
                        if ar.size==0
                                self.delete(key)
                        end
                end
        end
        def add(key, val)
                ar = self[key]
                if !ar
                        ar = []
                        self[key] = ar
                end
                ar.delete(val)
                ar << val
        end
        private
        def []=(key, val)
                super
        end
        class << self
                def test()
                        ha = Hash_of_arrays.new
                        ha.add("x", "a")
                        ha.add("x", "b")
                        ar = ha["x"]
                        U.assert_eq(2, ar.size)
                        ha.add("x", "b")
                        ar = ha["x"]
                        U.assert_eq(2, ar.size)
                        ha.delete_val("x", "b")
                        ar = ha["x"]
                        U.assert_eq(1, ar.size)
                        ha.delete_val("x", "a")
                        U.assert(!ha.has_key?("x"))
                end
        end
end

class Hash_of_n < Hash
        def add(key, val)
                U.assert(val.is_a?(Fixnum) || val.is_a?(Float))
                n = self[key]
                if !n
                        self[key] = n = 0
                end
                self[key] += val
        end
        private
        class << self
                def test()
                        hd = Hash_of_n.new
                        hd.add("x", 7)
                        U.assert_eq(7, hd["x"])
                        hd.add("x", 10)
                        U.assert_eq(17, hd["x"])
                end
        end
end
class U
        DAYS_BETWEEN_LOGS = 8

        LOG_ALL = 0
        LOG_DEBUG = 1
        LOG_INFO = 2
        LOG_WARNING = 3
        LOG_ERROR = 4
        LOG_ALWAYS = 5
        
        MAIL_MODE_MOCK = 0
        MAIL_MODE_SMTP = 1
        MAIL_MODE_TEST = 2
        class << self
                attr_accessor :log_level
                attr_accessor :log_indent
                attr_accessor :mail_mode
                attr_accessor :test_mode
                attr_accessor :dry_mode
                attr_accessor :raise_if_fail
                attr_accessor :test_exit_code
                attr_accessor :trace
                @@t = nil

                def init(mail_mode = U::MAIL_MODE_MOCK, date = nil)
                        # for mail: http://stackoverflow.com/questions/12884711/how-to-send-email-via-smtp-with-rubys-mail-gem
                        U.mail_mode = mail_mode
                        U.eval_f(ENV["HOME"] + "/.ruby_u", true)
                        U.log_level = U::LOG_ERROR
                        U.init_default_t_if_needed()
                        U.test_exit_code = 0
                end
                def eval_f(fn, ok_if_nonexistent=false)
                        if !File.exist?(fn)
                                if !ok_if_nonexistent
                                        raise "could not find #{fn} to eval ruby code"
                                end
                                return
                        end
                        code = IO.read(fn)
                        eval(code)
                end
                def make_orcl_date(date_string)
                        make_orcl_datetime(date_string)
                end
                def make_orcl_datetime(date_string)
                        print "make_orcl_date(#{date_string})... " if U.trace
                        d = Time.parse(date_string)
                        print "ruby date #{d}... " if U.trace
                        hour_minute_second = d.strftime("%H:%M:%S")
                        orcl_date_string = sprintf("TO_TIMESTAMP('%04d/%02d/%02d #{hour_minute_second}', 'yyyy/mm/dd hh24:mi:ss')", d.year, d.month, d.day)
                        puts orcl_date_string if U.trace
                        orcl_date_string
                end
                def make_sql_string(s)
                        if s
                                "'#{s.gsub("'", "''")}'"
                        else
                                "null"
                        end
                end
                def assert_file_exists(fn)
                        U.assert(File.exists?(fn), "could not find file #{fn} (looking from #{File.dirname(".")}")
                end
                def properties_read(fn)
                        h = Hash.new
                        U.assert_file_exists(fn)
                        IO.readlines(fn).each do | line |
                                assert(line =~ /(.*)=(.*)/)
                                property_name = $1
                                val = $2
                                h[property_name] = val
                        end
                        h
                end
                def unix_timestamp_to_date(seconds_since_epoch_integer)
                        #DateTime.strptime(seconds_since_epoch_integer.to_s,'%s')
                        Time.at(seconds_since_epoch_integer).to_datetime
                end
                def assert_string_contains(z, str, msg=nil)
                        if msg
                                msg << ": "
                        else
                                msg = ""
                        end

                        if !str.include?(z)
                                U.assert(false, "#{msg}expected to see \"#{z}\" in \"#{str}\"")
                        end
                end
                def host_name_to_DC(host_name)
                        case host_name
                        when /^adc/
                                "ADC"
                        when /^slc/
                                "UCF"
                        when /^blr/
                                "IDC"
                        when /^llg/
                                "UK"
                        else
                                U.assert(false, "could not determine DC for #{host_name}")
                                "DC?"
                        end
                end
                def t_to_s(t)
                        U.strftime("%H:%M:%S", t)
                end
                def system(cmd, input=nil, dir=nil)
                        t_preamble = ''
                        if dir
                                Dir.chdir(dir)
                                t_preamble << "cd \"#{dir}\"; "
                        end
                        puts "#{t_preamble}#{cmd}" if U.trace
                        if U.dry_mode
                                return "No output from U.system(#{cmd}) because we are in dry run mode..."
                        end
                        Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
                                if input
                                        stdin.write(input)
                                end
                                stdin.close

                                out = stdout.read
                                err = stderr.read
                                puts "#{cmd} -> out=#{out}, err=#{err}" if U.trace
                                # http://stackoverflow.com/questions/15023944/how-to-retrieve-exit-status-from-ruby-open3-popen3
                                if !wait_thr.value.success?
                                        raise "error: bad exit code from #{cmd}: #{err}"
                                end
                                out
                        end
                end
                def system_as_list(cmd, input=nil, dir=nil)
                        U.system(cmd, input, dir).split("\n")
                end
                def strftime(patt, t=Time.now)
                        t.strftime(patt)
                end
                def seconds_to_s(seconds)
                        indication_that_we_arent_very_precise = "about "
                        if seconds < 60
                                time_type = "second"
                                n = seconds.round
                                indication_that_we_arent_very_precise = ''
                        elsif seconds < 6000
                                time_type = "minute"
                                n = (seconds.to_f / 60).round
                        elsif seconds < (3600 * 72)
                                time_type = "hour"
                                n = (seconds.to_f / 3600).round
                        else
                                time_type = "day"
                                n = (seconds.to_f / (3600 * 24)).round
                        end
                        if n == 1
                                z = "#{indication_that_we_arent_very_precise}1 #{time_type}"
                        else
                                z = "#{indication_that_we_arent_very_precise}#{n} #{time_type}s"
                        end
                        #puts "seconds_to_s(#{seconds}) -> #{z}"
                        z
                end
                def test_mail()
                        # NOT TESTED
                        U.mail_mode = U::MAIL_MODE_TEST

                        lines = U.mail_mode("abc@x.com", "some subject", "mail about xyz@x.com\n and other stuff about def@x.com\n", false)
                        U.assert_eq("To: abc@x.com\n", lines[0])
                        
                        lines = U.mail_mode("abc@x.com", "some subject", "mail about xyz@x.com\n and other stuff about def@x.com\n", false)
                        U.assert_eq("To: abc@x.com, xyz@x.com, def@x.com\n", lines[0])
                end
                def last_line_that_matches(re, lines)
                        lines.reverse_each do | line |
                                if re.match(line)
                                        return line
                                end
                        end
                        return nil
                end
                def file_tmp_name(base_name='', ext='', dir=nil)
                        id = Thread.current.hash * Time.now.to_i % 2**32
                        name = "%s%d.%s" % [base_name, id, ext]
                        if !dir
                                dir = ENV["TMP"]
                        end
                        dir ? File.join(dir, name) : name
                end
                def rest_get(url)
                        resp = Net::HTTP.get_response(URI.parse(url))
                        resp.body
                end

                def rest_get_json(url)
                        x = U.rest_get(url)
                        JSON.parse(x)
                end
                def mail(to, subject, body, send_to_emails_grepped_in_body=false)
                        if send_to_emails_grepped_in_body
                                to << body.grep(/(\w+@\w+)/) { "$1" }
                        end
                        case U.mail_mode
                        when U::MAIL_MODE_TEST || U::MAIL_MODE_MOCK
                                z = "mail to #{to}\nsubject \"#{subject}\":\n" + body + '\n'
                                print z if U.mail_mode == U::MAIL_MODE_MOCK
                                return z
                        when U::MAIL_MODE_SMTP
                   raise "IMPL"
                        else
                                raise "bad U.mail_mode#{U.mail_mode}"
                        end
                end
                def property_save(key, val)
                        `prop_persistent_manage.sh "#{key}" "#{val}"`
                end
                def property_read(key)
                        `prop_persistent_manage.sh -read "#{key}"`.chomp
                end
                def system_loudly(cmd)
                        puts "Executing #{cmd}..."
                        puts `#{cmd}`
                        puts "EOD"
                end
                def honk(s, log_level=nil)
                        if !log_level || log_level >= U.log_level
                                puts "---------------------------------------------------------------------------------"
                                puts s
                                puts "---------------------------------------------------------------------------------"
                        end
                end
                def print_sym(sym)
                        U.print_s(sym, 8)
                end
                def print_s(s, cols)
                        sprintf("%#{cols}s", s)
                end
                def print_int(n)
                        sprintf("%5d", n.to_i)
                end
                def print_f(n, precision=nil, suppress_positivity_space=false)
                        if precision == nil
                                precision = 4
                        end
                        if suppress_positivity_space
                                space_if_positive = ""
                        end
                        if n==nil
                                space_if_positive = " "
                                sprintf("%s%#{precision}s", space_if_positive, "nil")
                        else
                                space_if_positive = (n >= 0 ? " " : "")
                                sprintf("%s%.#{precision}f", space_if_positive, n.to_f)
                        end
                end
                def print_p(p)
                        print_f(p, 2)
                end
                def print_hash(h, name=nil, indentation="\t")
                        #return pp(h)
                        #return JSON.pretty_generate(h)
                        eol = "\n"
                        z = ""
                        z << indentation
                        if name
                                z << name << " = "
                        end
                        z << "#{indentation}{"
                        h.keys.each do |key|
                                z << "#{eol}#{indentation}\t\"#{key}\" => #{U.print_ruby_literal(h[key])}"
                                eol = ",\n"
                        end
                        z << "\n#{indentation}}\n"
                        z
                end
                def print_bool(b)
                        if b
                                "true"
                        else
                                "false"
                        end
                end
                def print_ruby_literal(z)
                        if z.is_a?(String)
                                "\"#{z}\""
                        elsif z.is_a?(Fixnum) || z.is_a?(Float)
                                "#{z.to_s}"
                        else
                                (z ? "true" : "false")
                        end
                end
                def rolling_avg(new_n, old_n, max_decline_c=40, decline_c=40)
                        # max_decline_c to quickly adjust small samples
                        decline_c = [ decline_c, max_decline_c ].min
                        (new_n + ((decline_c - 1) * old_n)) / decline_c
                end
                def t()
                        if @@t==nil
                                if !U.test_mode
                                        raise "we are not in test mode and @@t is not set -- has initialization been done correctly?"
                                end
                                @@t = "2082/10/10.0100"
                        end
                        @@t
                end
                def init_default_t_if_needed()
                        if @@t==nil
                                @@t = "1999/10/10.0849"
                        end
                end
                def t=(new_t)
                        if new_t == nil
                                @@t = nil
                                U.assert(U.test_mode, "initializing t=nil for a new test")
                                return
                        end
                        if @@t!=nil
                                U.assert(U.t <= new_t, "only moving forward in time is supported, but #{new_t} is earlier than the old time #{U.t}")
                        end
                        new_day = U.t_extract_day(new_t)
                        @@t = new_t
                        if new_day != U.t_day
                                U.t_days_since_last_log += 1
                                if !U.test_mode && U.log_level<=U::LOG_WARNING && U::DAYS_BETWEEN_LOGS <= U.t_days_since_last_log
                                        U.log(",,,")
                                        U.t_days_since_last_log = 0
                                end
                        end
                        U.t_day = new_day
                end
                def t_extract_day(t)
                        d_plus = t.sub(/^\d\d\d\d\/\d\d\//, '')
                        d = d_plus.sub(/\..*/, '')
                        U.assert(d =~ /^\d\d$/, "unexpected #{d} from #{t}")
                        d
                end
                def assert_file_contains(fn, expected_contents)
                        actual_contents = IO.read(fn)
                        U.assert_eq(expected_contents, actual_contents, "contents of #{fn}")
                end
                def assert_xform(expected_output, input, method, label=nil)
                        actual_output = method.call(input)
                        U.assert_eq(expected_output, actual_output, "test transforming #{input}")
                end
                def assert_eq(expected, actual, caller_msg=nil, raise_if_fail=false)
                        U.init unless U.log_level
                        
                        expected.gsub!(/^\s*/, '') if expected.is_a?(String)
                        
                        if !expected.eql?(actual)
                                expected = "nil" if expected==nil
                                actual   = "nil" if   actual==nil
                                if caller_msg
                                        caller_msg = "#{caller_msg}: "
                                end
                                multiline = (expected =~ /\n/)
                                if multiline
                                        msg = "MISMATCH: #{caller_msg}expected:\n#{expected}EOD\nactual:\n#{actual}EOD\n"
                                else
                                        msg = "MISMATCH: #{caller_msg}expected:\n#{expected}\nactual:\n#{actual}\n"
                                end
                                U.assert(false, msg, raise_if_fail)
                                ok = false
                        else
                                z = "OK U.assert_eq: #{expected} == #{actual}"
                                U.log(z)
                                puts U.truncate_string(z)
                                ok = true
                        end
                        return ok
                end
                def assert_is_t(t)
                        U.assert(t =~ /^\d\d\d\d\/\d\d\/\d\d\.\d\d\d\d$/, "bad date/time #{t}")
                end
                def assert_ne(v1, v2, msg=nil)
                        if v1==v2
                                if !msg
                                        msg = ""
                                else
                                        msg << ": "
                                end

                                s1 = v1.to_s
                                s2 = v2.to_s
                                U.assert_eq(s1, s2) # checking to see if == and to_s somehow not equivalent
                                msg << "expected different values, but saw #{s1}"
                                U.assert(false, msg)
                        else
                                U.log("U.assert_ne: #{v1} != #{v2} OK") if U.log_level<=U::LOG_ALL
                        end
                end
                def exit_test()
                        if U.test_exit_code == 0
                                puts "OK #{U.test_mode}"
                        else
                                puts "FAILED #{U.test_mode}"
                        end
                        exit(U.test_exit_code)
                end
                def assert(expr, msg=nil, raise_if_fail=nil)
                        U.init unless U.log_level
                        if !expr
                                U.test_exit_code = -1
                                if !msg
                                        msg = "assertion failed"
                                end
                                
                                msg << " at #{U.t}" unless U.t.start_with?("1999") # which would indicate the time was never set
                                
                                if raise_if_fail || U.raise_if_fail
                                        raise Test_assertion.new(msg)
                                else
                                        puts msg
                                end
                        else
                                U.log("U.assert: #{expr} OK") if U.log_level<=U::LOG_ALL
                        end
                end
                def assert_type(expr, typ)
                        if !expr.is_a?(typ)
                                U.assert(false, "type mismatch: expected #{typ} for #{expr}")
                        else
                                U.log("U.assert_type: #{expr}, #{typ} OK") if U.log_level<=U::LOG_ALL
                        end
                end
                def assert_no_nil_entries_in_array(ar, msg=nil)
                        ar.each_with_index do |a, j|
                                if a==nil
                                        if !msg
                                                msg = ""
                                        else
                                                msg << ": "
                                        end
                                        U.assert(false, "#{msg}null entry at #{j}")
                                end
                        end
                end
                def t_to_type(t1, t2=nil)
                        if t1 =~ /06[345].$/ || t1 =~ /0[789]..$/ || t1 =~ /1[012]..$/
                                type1 = "session"
                        else
                                type1 = "outside"
                        end
                        if t2
                                type2 = U.t_to_type(t2)
                                if type1!=type2
                                        return "mixed"
                                end
                        end
                        return type1
                end
                def batting_avg(hits, atbats)
                        sprintf("%0.3f %5d/%-5d", (hits / atbats.to_f), hits, atbats)
                end
                def warn(s, count_of_frames_to_be_discarded=0, discard_calling_frames=false)
                        backtrace = Thread.current.backtrace
                        0.upto(count_of_frames_to_be_discarded) do
                                backtrace.shift # get rid of U.warn stackframe + whatever the caller finds not useful
                        end
                        backtrace[0].sub!(/(:\d+:).*/, "\\1 warning: #{s}")
                        if discard_calling_frames
                                puts backtrace[0]
                        else
                                puts "#{backtrace.join("\n")}"
                        end
                end
                def log(s, prepend_timestamp_to_output=true)
                        self.log_level = LOG_ERROR if !self.log_level
                        if self.log_level < 4
                                z = ''
                                if prepend_timestamp_to_output
                                        z << U.t << " "
                                end
                                if !U.log_indent
                                        U.log_indent = ''
                                else
                                        z << U.log_indent
                                end
                                z << s
                                z.gsub!(/\n/, "#{U.log_indent}\n")
                        end
                        puts z if z && z!=''
                end
                def test_rolling_avg()
                        avg = 1
                        avg = test_rolling_avg1(2.0, avg, 2, 40)
                        avg = test_rolling_avg1(3.0, avg, 3, 40)
                        avg = test_rolling_avg1(2.1, avg, 4, 40)
                        avg = test_rolling_avg1(1.0, avg, 5, 40)
                        avg = test_rolling_avg1(1.5, avg, 6, 40)
                        avg = test_rolling_avg1(1.4, avg, 7, 40)
                        avg = test_rolling_avg1(1.6, avg, 8, 40)
                        avg = test_rolling_avg1(1.2, avg, 9, 40)
                        avg = test_rolling_avg1(5.0, avg, 10, 40)
                        avg = test_rolling_avg1(5.2, avg, 11, 40)
                        avg = test_rolling_avg1(1.4, avg, 12, 40)
                        avg = test_rolling_avg1(1.3, avg, 13, 40)
                        avg = test_rolling_avg1(1.0, avg, 14, 40)
                        avg = test_rolling_avg1(1.5, avg, 15, 40)
                        avg = test_rolling_avg1(1.2, avg, 16, 40)
                        avg = test_rolling_avg1(1.5, avg, 17, 40)
                        avg = test_rolling_avg1(1.3, avg, 18, 40)
                        avg = test_rolling_avg1(1.7, avg, 19, 40)
                        exit(0)
                end
                def test_rolling_avg1(new_n, old_avg, max_decline_c, decline_c)
                        avg = U.rolling_avg(new_n, old_avg, max_decline_c, decline_c)
                        puts "U.rolling_avg(#{new_n}, #{old_avg}, #{max_decline_c}, #{decline_c}) -> #{avg}"
                        avg
                end
                def test()
                        U.test_mode = true
                        U.assert_eq("42 seconds", U.seconds_to_s(42))
                        U.assert_eq("about 1 minute", U.seconds_to_s(62))
                        U.assert_eq("about 2 minutes", U.seconds_to_s(110))
                        U.assert_eq("about 94 minutes", U.seconds_to_s((94 * 60) - 4))
                        U.assert_eq("about 2 hours", U.seconds_to_s(132 * 60))
                        U.assert_eq("about 2 hours", U.seconds_to_s(110 * 60))
                        U.assert_eq("about 71 hours", U.seconds_to_s((71 * 3600) + 9))
                        U.assert_eq("about 71 hours", U.seconds_to_s((71 * 3600) - 9))
                        U.assert_eq("about 3 days", U.seconds_to_s((73 * 3600) - 9))
                        U.assert_eq("about 3 days", U.seconds_to_s((73 * 3600) + 9))
                        U.property_save("xyz", "abc")
                        U.assert_eq("abc", U.property_read("xyz"))
                        #U.test_mail()
                        U.assert_eq("42 seconds", U.seconds_to_s(42))
                        U.assert_eq("about 1 minute", U.seconds_to_s(62))
                        U.assert_eq("about 2 minutes", U.seconds_to_s(110))
                        U.assert_eq("about 94 minutes", U.seconds_to_s((94 * 60) - 4))
                        U.assert_eq("about 2 hours", U.seconds_to_s(132 * 60))
                        U.assert_eq("about 2 hours", U.seconds_to_s(110 * 60))
                        U.assert_eq("about 71 hours", U.seconds_to_s((71 * 3600) + 9))
                        U.assert_eq("about 71 hours", U.seconds_to_s((71 * 3600) - 9))
                        U.assert_eq("about 3 days", U.seconds_to_s((73 * 3600) - 9))
                        U.assert_eq("about 3 days", U.seconds_to_s((73 * 3600) + 9))
                        U.property_save("xyz", "abc")
                        U.assert_eq("abc", U.property_read("xyz"))
                        #U.test_mail()
                        #U.test_rolling_avg()
                        U.init(true, "2014/10/10.0600")

                        U.assert_eq(1.975, U.rolling_avg(40.0, 1.0))
                        U.assert_eq(" 123.1235", U.print_f(123.12345), 'U.print_f(123.12345)')
                        U.assert_eq("1.000     4/4    ", U.batting_avg(4, 4), 'U.batting_avg(4, 4)')
                        U.assert_eq("0.500     2/4    ", U.batting_avg(2, 4), 'U.batting_avg(2, 4)')
                        U.assert_eq("0.000     0/4    ", U.batting_avg(0, 4), 'U.batting_avg(0, 4)')
                        U.assert_eq("0.667     2/3    ", U.batting_avg(2, 3), 'U.batting_avg(2, 3)')

                        Hash_of_n.test
                        Hash_of_arrays.test



                        #
                        #
                        #
                        # should use U.assert_xform for this
                        U.assert_eq("session", U.t_to_type("2014/10/10.0700"), "unexpected for 2014/10/10.0700")
                        U.assert_eq("session", U.t_to_type("2014/10/10.0630"), "unexpected for 2014/10/10.0630")
                        U.assert_eq("session", U.t_to_type("2014/10/10.1259"), "unexpected for 2014/10/10.1259")
                        U.assert_eq("outside", U.t_to_type("2014/10/10.0629"), "unexpected for 2014/10/10.0629")
                        U.assert_eq("outside", U.t_to_type("2014/10/10.1302"), "unexpected for 2014/10/10.1302")
                        U.assert_eq("session", U.t_to_type("2014/10/10.1002"), "unexpected for 2014/10/10.1002")
                        U.assert_eq("session", U.t_to_type("2014/10/10.1000", "2014/10/10.1102"))
                        U.assert_eq("mixed", U.t_to_type("2014/10/10.1000", "2014/10/10.1302"))
                        #
                        #
                        #

                        puts "OK u"
                end
                def only_child_of(dir)
                        children = Dir.glob("#{dir}/*")
                        raise "expected only one child for dir #{dir}, but seeing #{children.size}" if children.size > 1
                        raise "expected an only child for dir #{dir}, but did not see any children at all" if children.size == 0
                        children[0]
                end
                def file_rewritten_since_last_look(fn)
                        fn_persistent_attrib_key_prefix = fn
                        current_size = File.size(fn)
                        last_size = U.property_read_int("#{fn}.size")
                        rc = nil
                        if last_size && (current_size < last_size)
                                rc = true
                        else
                                current_line1 = `head -1 "#{fn}"`.chomp
                                last_line1 = U.property_read("#{fn_persistent_attrib_key_prefix}.line1")
                                if current_line1 != last_line1
                                        rc = true
                                end
                        end
                        U.property_save("#{fn_persistent_attrib_key_prefix}.line1", current_line1)
                        U.property_save("#{fn_persistent_attrib_key_prefix}.size", current_size.to_s)
                        return false
                end
                # e.g.,
                # U.print_hash_of_counters(Check_Log.categorized_errors, "error category", Check_Log::ALL)
                #     %          count error category
                # ----- -------------- --------------
                #100.00            364 (all messages)
                # 62.91            229 HTTP error code 409
                # 27.75            101 v2 repository request
                #  3.85             14 HTTP error code 403
                #  2.20              8 v1 repository request
                #  1.92              7 Error in getting information: connect timed out
                #  1.10              4 Error in getting information: Read timed out
                #
                def print_hash_of_counters(h, counter_column_header, total_message_count_key=nil, show_percentage=true, numeric_column_header="count")
                        raise "odd, we don't need the total_message_count_key unless we are showing percent" if total_message_count_key && show_percentage
                        sorted_keys = h.keys.sort {|a,b| h[b] <=> h[a]}
                        if !sorted_keys.empty?
                                print sprintf "%6s ", "%" if show_percentage
                                puts sprintf "%s %s", numeric_column_header, counter_column_header
                                
                                print "------ " if show_percentage
                                z = ("-" * numeric_column_header.length)
                                print z
                                puts " --------------"
                                if show_percentage
                                        if total_message_count_key
                                                total_message_count = h[total_message_count_key]
                                        else
                                                total_message_count = h.values.reduce(:+)
                                        end
                                        raise "nothing for total (#{h})" unless total_message_count
                                end
                                sorted_keys.each do | key |
                                        message_count = h[key]
                                        raise "nothing for #{key}" unless message_count
                                        if show_percentage
                                                percentage = 100.0 * message_count / total_message_count
                                                print sprintf "%6.2f ", percentage
                                        end
                                        puts sprintf "%#{numeric_column_header.length}d %s", h[key], key
                                end
                        end
                end
                def truncate_string(s, max_len=130)
                        if s.size < max_len
                                s
                        else
                                "#{s.slice(0..max_len)}..."
                        end
                end
        end
end