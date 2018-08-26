require_relative 'u.rb'
require_relative 'financial_document.rb'

class Test_Document_Parser
        def initialize()
	end
	class << self
                attr_accessor :testing_doc_typing
                def test_doc_typing1(pdf, expected_doc_type)
                        fd = Financial_Document.new(pdf)
                        U.testing_fn(pdf)
                        if Test_Document_Parser.testing_doc_typing
                                U.assert_eq(expected_doc_type, fd.get_type, "test_doc_typing")
                        end
                end
                def test_doc_typing(dir, expected_doc_type)
                        Dir["#{dir}/*.pdf"].each do | pdf |
                                test_doc_typing1(pdf, expected_doc_type)
                        end
                end
                def test_doc1(base_fn, expected_doc_type, expected_stock_count, explanatory_note)
                        fn = "../test_docs/#{base_fn}"
                        U.testing_fn(fn)
                        fd = Financial_Document.new(fn)
                        test_doc_typing1(fn, expected_doc_type)
                        U.assert_eq(expected_stock_count, fd.get_stock_count, "doc stock count test #{explanatory_note}")
                end
                def test_get_symbol(dir)
                        Dir["#{dir}/**/*.pdf"].each do | pdf |
                                U.testing_fn(pdf)
                                if pdf !~ /^([A-Z]+) /
                                        #puts "warning: could not find symbol in file #{pdf}"
                                else
                                        puts "NICE: found symbol in file #{pdf}"
                                        symbol_in_fn = $1
                                        fd = Financial_Document.new(fn)
                                        if fd.text !~ /#{symbol_in_fn}/
                                                puts "warning, could not find #{symbol_in_fn} in the text of #{pdf}"
                                        else
                                                puts "OK found #{symbol_in_fn} in the text of #{pdf}"
                                        end
                                end
                        end
                end
                def go()
                        U.init
                        U.log_level = U::LOG_INFO
                        
                        puts "not testing doc_type extraction for now..."
                        puts "not testing doc_type extraction for now..."
                        puts "not testing doc_type extraction for now..."
                        Test_Document_Parser.testing_doc_typing = false
                        
                        
                        
                        U.adding_reference_to_txt = true
                        ##test_doc1("PPBN_Q2_2018_Report.pdf", Financial_Document::TYPE_QUARTERLY_REPORT, 1540140, "(Melanie 1529033) Weighted average share outstanding basic: 1,540,141 (net income: $2,187,000/EPS basic: $1.42)")
                        #table test_doc1("PNBI_Q1_2018_Report.pdf", Financial_Document::TYPE_QUARTERLY_REPORT, 974595, "(Stockholder's Equity: $27,698,000/Book value per share: $28.42) *Note equity is written in 000's; Weighted average share outstanding basic: $971,795 (Net Income:$758,000/EPS: $0.78)")
                        ##test_doc1("PCLB_Q2_2018_Report.pdf", Financial_Document::TYPE_QUARTERLY_REPORT, 1043505, "Weighted average share outstanding basic: 1,043,505 (page 8) Weighted average share outstanding diluted: 1,043,505 (page 8)")
                        test_doc1("PBNK_Q2_2018_Report.pdf", Financial_Document::TYPE_QUARTERLY_REPORT, 4072102, "(share outstanding at period end) Weighted average share outstanding basic: 4,065,714 (Net Income: 1,423,000/Basic Earnings per Share (EPS): $0.35)*note net income is written in 000's on the report)")
                        puts "vvvvvvvvvvvvvvvvvvvvvvvvv"; exit
                        test_doc1("NUBC_Q1_2018_Report.pdf", Financial_Document::TYPE_QUARTERLY_REPORT, 1328358, "(1,502,500 issued less 174,142 treasury stock).  Weighted average share outs (basic assumed): 1,328,358")
                        test_doc1("MCBI_Q2_2018_Report.pdf", Financial_Document::TYPE_QUARTERLY_REPORT, 6279847, "income of $2.449 million for the second quarter of 2018. Earnings per fully diluted share for the quarter ended June 30, 2018 totaled $0.39 versus")
                        test_doc1("MCBK_Q2_2018_Report.pdf", Financial_Document::TYPE_QUARTERLY_REPORT, 2830188, "net income for the three months ended June 30, 2018 was $1.5 million or $0.53 per diluted share, compared to net income of $1.1 million or $0.41 per diluted share for the same period in 2017")
                        test_doc1("MCHT_Q2_2018_Report.pdf", Financial_Document::TYPE_QUARTERLY_REPORT, 3056843, "Average Common Share Outstanding Basic- 3,056,843")
                        test_doc1("MFGI_Q2_2018_Report.pdf", Financial_Document::TYPE_QUARTERLY_REPORT, 2848521, "in the text on the first page")
                        test_doc1("MNMB_Q1_2018_Report.pdf", Financial_Document::TYPE_QUARTERLY_REPORT, 1330338, "1,330,338 shares issued")
                        test_doc1("MSBC_Q2_2018_Report.pdf", Financial_Document::TYPE_QUARTERLY_REPORT, 1757597, "table")
                        test_doc1("NASB_Q2_2018_Report.pdf", Financial_Document::TYPE_QUARTERLY_REPORT, 7384851, "9,865,281 shares issued less 2,480,430 shares outstanding Average Common Share Outstanding Basic-7,384,851 (second page)")
                        p = "#{ENV['DOWNLOADS']}/parser"
                        if Dir.exist?(p)
                                test_doc_typing("#{p}/Quarterly_Reports", Financial_Document::TYPE_QUARTERLY_REPORT)
                                test_doc_typing("#{p}/Annual_Reports",    Financial_Document::TYPE_ANNUAL_REPORT)
                                test_get_symbol(p)
                        end
                end
        end
end
j = 0
while ARGV.size > j do
        arg = ARGV[j]
        case arg
        when "-@@"
                #Test_Document_Parser.@@ = @@
        when "-@@xxxx"
                j = j + 1
                #@@ = ARGV[j]
        else
                raise "did not understand \"#{ARGV[j]}\""
                break
        end
        j += 1
end
Test_Document_Parser.go
