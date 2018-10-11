class Error_record < Exception
        attr_accessor :emsg
        attr_accessor :http_response_code
        def initialize(emsg, http_response_code=nil)
                self.emsg = emsg # If we want to encapsulate stack trace in emsg, add this:              + "\n" + self.current_backtrace
                self.http_response_code = http_response_code
        end
        def current_backtrace()
                # get stack, but don't include Error_record frames
                z = ""
                skipping_initial_error_record_frames = true
                Thread.current.backtrace.each do | frame |
                        if skipping_initial_error_record_frames
                                if frame =~ /:in `raise'$/
                                        skipping_initial_error_record_frames = false
                                end
                        else
                                z << frame << "\n"
                        end
                end
                z
        end
        def to_s()
                z = "Error_record("
                if self.http_response_code
                        z << "http_response_code=#{self.http_response_code}, "
                else
                        z << ""
                end
                z << "emsg=#{self.emsg})"
        end
        class << self
                attr_accessor :emsg
                attr_accessor :http_response_code
        end
end

class Error_holder
        attr_accessor :error
        def exception()
                self.error
        end
        def raise(emsg, http_response_code=nil)
                self.error = Error_record.new(emsg, http_response_code)
                Kernel.raise self
        end
        class << self
                def raise(emsg, http_response_code=nil)
                        eh = Error_holder.new
                        eh.raise(emsg, http_response_code)
                end
        end
end
