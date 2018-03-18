require_relative 'u'
require_relative 'error_holder'
require_relative 'file_set'
require_relative 'json_obj'
require_relative 'source_control_repo'
require_relative 'cspec'
require_relative 'cspec_set'
require 'rubygems'
require 'xmlsimple'
require 'fileutils'
require 'pp'
require 'net/http'
require 'json'

class Global < Error_holder
        class << self
                attr_accessor :data_json_fn
                attr_accessor :data
                def init_data()
                        if !data
                                if !data_json_fn
                                        data_json_fn = "/scratch/change_tracker/change_tracker.json"
                                end
                                if File.exist?(data_json_fn)
                                        self.data = Json_obj.new(IO.read(data_json_fn))
                                else
                                        self.data = Json_obj.new
                                end
                        end
                end
                def get(key, default_value = nil)
                        init_data
                        data.get(key, default_value)
                end
                def get_scratch_dir(key)
                        raise "bad key" unless key
                        scratch_dir_root = get("scratch_dir", "/scratch/change_tracker")
                        key = key.gsub(/[^\w]/, "_")
                        scratch_dir = scratch_dir_root + "/" + key
                        FileUtils.mkdir_p(scratch_dir)
                        scratch_dir
                end
                def has_key?(key)
                        data.has_key?(key)
                end
                def get_credentials(key, ok_if_nonexistent = false)
                        u_key = "#{key}.username"
                        pw_key = "#{key}.pw"
                        if has_key?(u_key)
                                return get(u_key), get(pw_key)
                        elsif ok_if_nonexistent
                                return nil
                        else
                                raise "cannot find credentials for #{key}"
                        end
                end
                def test()
                        U.assert_eq("test.val", Global.get("test.key"), "Global.test.key")
                        U.assert_eq("default val", Global.get("test.nonexistent_key", "default val"), "Global.test.nonexistent key")
                        username, pw = Global.get_credentials("test_server")
                        U.assert_eq("some_username", username, "Global.test.username")
                        U.assert_eq("some_pw",       pw,       "Global.test.pw")
                end
        end
end

class Change_tracker
        HOST_NAME_DEFAULT = "localhost"
        PORT_DEFAULT = 11111

        attr_accessor :host_name
        attr_accessor :port
        def initialize(host_name = Change_tracker::HOST_NAME_DEFAULT, port = Change_tracker::PORT_DEFAULT)
                self.host_name = host_name
                self.port = port.to_s
        end
        def to_s()
                "Change_tracker(#{self.host_name}:#{self.port})"
        end
        def eql?(other)
                self.host_name.eql?(other.host_name) && self.port.eql?(other.port)
        end
        class << self
        end
end

class Change_tracker_app
        attr_accessor :json_fn1
        attr_accessor :json_fn2
        
        attr_accessor :v_info1
        attr_accessor :v_info2
        
        def usage(msg)
                puts "Usage: ruby change_mon_show.rb VERSION_JSON_FILE1 VERSION_JSON_FILE2: #{msg}"
                exit
        end
        def go()
                if !json_fn1
                        usage('no args seen')
                end
                if !json_fn2
                        usage('missing VERSION_JSON_FILE2')
                end
                cspec_set1 = Cspec_set.from_file(json_fn1)
                cspec_set2 = Cspec_set.from_file(json_fn2)
                cspec_set2.list_files_added_or_updated_since(cspec_set1).each do | changed_file |
                        puts changed_file
                end
        end
end
