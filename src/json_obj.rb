class Json_obj
        attr_accessor :h
        def initialize(json_text = nil)
                if json_text
                        self.h = JSON.parse(json_text)
                else
                        self.h = Hash.new
                end
        end
        def array_of_json_to_s(a, multi_line_mode = false)
                z = nil
                a.each do | elt |
                        if !z
                                z = "["
                        else
                                z << ","
                        end
                        z << "\n" if multi_line_mode
                        z << elt.json
                end
                z << "\n" if multi_line_mode
                z << "]"
                z
        end
        def to_s()
                "Json_obj(#{self.h})"
        end
        def get(key, default_val = nil)
                if !self.h.has_key?(key)
                        if default_val
                                return default_val
                        else
                                raise "no match for key #{key} in #{self.h}"
                        end
                end
                h[key]
        end
        def has_key?(key)
                h.has_key?(key)
        end
end
