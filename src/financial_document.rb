class Financial_Document
        TYPE_UNKNOWN = "Unknown"
        TYPE_ANNUAL_REPORT = "Annual Report - Company"
        TYPE_QUARTERLY_REPORT = "Quarterly Report - Company"
        TYPE_10K = "10-K (SEC)"

        attr_accessor :date
        attr_accessor :fn
        attr_accessor :txt
        attr_accessor :flat_txt
        attr_accessor :type
        attr_accessor :universal_factor
        attr_accessor :universal_factor_shares
        def initialize(fn)
                raise "expected pdf, but saw #{fn}" unless fn =~ /\.pdf$/
                self.fn = fn
                txt_fn = fn.sub(/.pdf$/, ".txt")
                if !File.exist?(txt_fn)
                        U.system("pdftotext \"#{fn}\" > \"#{txt_fn}\"")
                        puts "warning: no txt for #{fn}"
                end
                if !File.exist?(txt_fn)
                        self.txt = ""
                else
                        self.txt = U.read_file(txt_fn)
                        self.flat_txt = self.txt.gsub(/\s+/, ' ')
                        self.set_universal_factors
                end
        end
        def to_s()
                self.fn
        end
        def set_universal_factors()
                self.universal_factor = 1
                self.universal_factor_shares = 1
                if self.flat_txt
                        if self.flat_txt =~ /in thousands,? except share/i
                                self.universal_factor = 1000
                        elsif self.flat_txt =~ /in thousands/i
                                self.universal_factor = 1000
                                self.universal_factor_shares = 1000
                        end 
                end
                U.log("#{self}.universal_factor_shares = #{self.universal_factor_shares}")
                U.log("#{self}.universal_factor = #{self.universal_factor}")
        end
        def get_date()
                "01/01/1970"
        end
        def find_explicit_stock_count()
                n = nil
                if self.txt
                        if self.flat_txt =~ /^.*?Weighted average basic (and diluted )?shares outstanding ([\d,]+)/
                                n = to_share_count_number($2)
                        end
                end
                U.log("#{self}.explicit_stock_count = #{n}")
                n
        end
        def to_share_count_number(s)
                to_number(s, self.universal_factor_shares)
        end 
        def to_number(s, factor = self.universal_factor)
                s.sub!(/^\$/, '')
                n = s.gsub(/,/, '').to_f
                if factor
                        n *= factor
                        n = n.round
                end
                n
        end
        def find_net_income()
                n = nil
                if self.txt
                        if self.txt =~ /Net income[\n\$]*([\d\.,]+)/
                                n = to_number($1)
                        end
                        if self.flat_txt =~ /^.*?For the \w+ months ended .*?reported net income of ([\$\d,]+)/
                                n = to_number($1)
                        end
                end
                U.log("#{self}.net_income = #{n}")
                n
        end
        def find_profit_per_share()
                n = nil
                if self.txt
                        if self.txt =~ /Net income per share:?[\s]*(Basic)?[\$\s]*([\d,]+\.\d\d)/
                                n = to_number($2, false)
                        elsif self.flat_txt =~ /^.*?Basic (and diluted )?earnings per share.*?\$\s*([\d,]+\.\d\d)/
                                n = to_number($2, false)
                        end
                end
                U.log("#{self}.profit_per_share = #{n}")
                n
        end
        def get_stock_count()
                stock_count = find_explicit_stock_count
                if !stock_count
                        net_income = find_net_income
                        if net_income
                                profit_per_share = find_profit_per_share
                                if profit_per_share
                                        stock_count = (net_income / profit_per_share).to_i
                                end
                        end
                end
                U.log("#{self}.stock_count = #{stock_count}")
                stock_count
        end
        def get_type()
                if !self.txt
                        return Financial_Document::TYPE_UNKNOWN
                end
                if self.txt =~ /10-K/
                        return Financial_Document::TYPE_10K
                end
                if self.txt =~ /Quarterly Report/
                        return Financial_Document::TYPE_QUARTERLY_REPORT
                end
                if self.txt =~ /Annual Report/
                        return Financial_Document::TYPE_ANNUAL_REPORT
                end
                return Financial_Document::TYPE_UNKNOWN
        end
        class << self
        end
end
