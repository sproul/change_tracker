require_relative 'u'
require_relative 'change_tracker'
require 'json'
require 'socket'

class User_error < Exception
        attr_accessor :emsg
        def initialize(s)
                self.emsg = s
        end
end

class Json_change_tracker
        TEST_REPO_NAME = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;"
        attr_accessor :op
        attr_accessor :error

        def initialize()
                if !Json_change_tracker.initialized
                        raise "Json_change_tracker.init must be called before Json_change_tracker objects are allocated"
                end
        end
        def error_msg(emsg)
                "<h3>Error: <font color=red>#{emsg}</font></h3>"
        end
        def exception()
                self.error
        end
        def get(h, key)
                if !h.has_key?(key)
                        self.error = User_error.new("did not find anything for key '#{key}'")
                        raise self
                end
                h[key]
        end
        def get_Compound_commit(h, cspec_key)
                cspec = get(h, cspec_key)
                deps_key = "#{cspec_key}_deps"
                if !h.has_key?(deps_key)
                        # executes auto-discovery in this case
                        return Compound_commit.from_spec(cspec)
                end
                array_of_dep_cspec = h[deps_key]
                deps = []
                array_of_dep_cspec.each do | dep_cspec |
                        deps << Git_commit.from_spec(dep_cspec)
                end
                puts "deps=#{deps}"
                Compound_commit.new(cspec, deps)
        end
        def get_Compound_commit_pair(h1, h2)
                cc1 = get_Compound_commit(h1, "cspec")
                cc2 = get_Compound_commit(h2, "cspec")
                return cc1, cc2
        end
        def usage(emsg)
                z = start_html_page()
                z << error_msg(emsg)
                z << "To manually interact with the change tracker, visit the <a href=/ui.htm>change tracker UI</a>.<br>"
                z << Json_change_tracker.examples(self.op)
                z
        end
        def start_html_page()
                %Q[<html xmlns="http://www.w3.org/1999/xhtml" lang="en"><!doctype html>
                <head>
                <meta http-equiv="Content-type" content="text/html;charset=UTF-8">
                <title>Change tracker</title>
                </head>
                <body bgcolor=\"#CCCCCC\"><font face=arial>]
        end
        def end_html_page()
                "</font></body></html>"
        end
        def system_error(emsg, backtrace=nil)
                # nicer formatting could be implemented here to make the error more presentable in the browser:
                z = start_html_page
                z << "<h4>Error encountered: " << error_msg(emsg)
                if backtrace
                        z << "#{backtrace.join("\n")}\n"
                end

                z
        end
        def go(op, json_text1, json_text2, pretty=false)
                if !op
                        return 400, usage("op is a required argument")
                end
                if !json_text1
                        return 400, usage("json1 is a required argument")
                end
                if !json_text2
                        return 400, usage("json2 is a required argument")
                end
                http_response_code = 200
                self.op = op
                
                h1 = nil
                begin
                        h1 = JSON.parse(json_text1)
                rescue JSON::ParserError => jpe
                        emsg = jpe.to_s
                end
                if !h1
                        return 400, usage("trouble parsing json1 \"#{json_text1}\": #{emsg}")
                end
                
                h2 = nil
                begin
                        h2 = JSON.parse(json_text2)
                rescue JSON::ParserError => jpe
                        emsg = jpe.to_s
                end
                if !h2
                        return 400, usage("trouble parsing json2 \"#{json_text2}\": #{emsg}")
                end
                
                json_output = nil
                begin
                        case self.op
                        when "list_bug_IDs_between"
                                cc1, cc2 = get_Compound_commit_pair(h1, h2)
                                x = cc2.list_bug_IDs_since(cc1)
                        when "list_changes_between"
                                cc1, cc2 = get_Compound_commit_pair(h1, h2)
                                x = cc2.list_changes_since(cc1)
                        when "list_files_changed_between"
                                cc1, cc2 = get_Compound_commit_pair(h1, h2)
                                x = cc2.list_files_changed_since(cc1)
                                json_output = x.to_json
                        else
                                return 400, usage("did not know how to interpret op '#{op}'")
                        end
                rescue Error_record => e_obj
                        return e_obj.http_response_code, system_error(e_obj.emsg)
                rescue RuntimeError => e_obj
                        # https://en.wikipedia.org/wiki/List_of_HTTP_status_codes
                        # 500 server error
                        # 501 not impl
                        return 500, system_error(e_obj.to_s, e_obj.backtrace)
                rescue User_error => e_obj
                        return 400, usage(e_obj.emsg)
                end
                if !json_output
                        x.each do | elt |
                                if !json_output
                                        json_output = "[\n"
                                else
                                        json_output << ",\n"
                                end
                                json_output << "\t" << elt.to_json
                        end
                        if !json_output
                                json_output = "["
                        end
                        json_output << "\n]\n"
                end
                if pretty
                        json_output = prettify_json(json_output)
                end
                puts json_output unless U.test_mode
                return http_response_code, json_output
        end
        def prettify_json(json)
                json_obj = JSON.parse(json)
                JSON.pretty_generate(json_obj)
        end
        class << self
                attr_accessor :initialized
                attr_accessor :examples_by_op
                attr_accessor :usage_full_examples
                attr_accessor :web_root
                def init(web_root)
                        Json_change_tracker.web_root = web_root
                        if !Json_change_tracker.examples_by_op
                                Json_change_tracker.examples_by_op = Hash.new
                                Json_change_tracker.examples_by_op["list_bug_IDs_between"] = init_example_for_op("list_bug_IDs_between", "@WEB_ROOT@/?pretty=true&op=list_bug_IDs_between&json1=%7B%22cspec%22%3A%22git%3Bgit.osn.oraclecorp.com%3Bosn/cec-server-integration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%22cspec_deps%22%3A%5B%22git%3Bgit.osn.oraclecorp.com%3Bccs/caas%3Bmaster%3Ba1466659536cf2225eadf56f43972a25e9ee1bed%22%2C%22git%3Bgit.osn.oraclecorp.com%3Bosn/cef%3Bmaster%3B749581bac1d93cda036d33fbbdbe95f7bd0987bf%22%5D%7D&json2=%7B%22cspec_deps%22%3A%5B%22git%3Bgit.osn.oraclecorp.com%3Bccs/caas%3Bmaster%3Ba1466659536cf2225eadf56f43972a25e9ee1bed%22%2C%22git%3Bgit.osn.oraclecorp.com%3Bosn/cef%3Bmaster%3B749581bac1d93cda036d33fbbdbe95f7bd0987bf%22%5D%2C%22cspec%22%3A%22git%3Bgit.osn.oraclecorp.com%3Bosn/cec-server-integration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%7D", %Q[{ "cspec": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64", "cspec_deps": [ "git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed", "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"] }], %Q[{ "cspec_deps": [ "git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed", "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"], "cspec": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"}])
                                
                                Json_change_tracker.examples_by_op["list_changes_between"] = init_example_for_op("list_changes_between", "@WEB_ROOT@/?pretty=true&op=list_changes_between&json1=%7B%22cspec%22%3A%22git%3Bgit.osn.oraclecorp.com%3Bosn/cec-server-integration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%22cspec_deps%22%3A%5B%22git%3Bgit.osn.oraclecorp.com%3Bccs/caas%3Bmaster%3Ba1466659536cf2225eadf56f43972a25e9ee1bed%22%2C%22git%3Bgit.osn.oraclecorp.com%3Bosn/cef%3Bmaster%3B749581bac1d93cda036d33fbbdbe95f7bd0987bf%22%5D%7D&json2=%7B%22cspec_deps%22%3A%5B%22git%3Bgit.osn.oraclecorp.com%3Bccs/caas%3Bmaster%3Ba1466659536cf2225eadf56f43972a25e9ee1bed%22%2C%22git%3Bgit.osn.oraclecorp.com%3Bosn/cef%3Bmaster%3B749581bac1d93cda036d33fbbdbe95f7bd0987bf%22%5D%2C%22cspec%22%3A%22git%3Bgit.osn.oraclecorp.com%3Bosn/cec-server-integration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%7D", %Q[{ "cspec": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64", "cspec_deps": [ "git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed", "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"] }], %Q[{ "cspec_deps": [ "git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed", "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"], "cspec": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"}])
                                
                                Json_change_tracker.examples_by_op["list_files_changed_between"] = init_example_for_op("list_files_changed_between", "@WEB_ROOT@/?pretty=true&op=list_files_changed_between&json1=%7B%22cspec%22%3A%22git%3Bgit.osn.oraclecorp.com%3Bosn/cec-server-integration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%22cspec_deps%22%3A%5B%22git%3Bgit.osn.oraclecorp.com%3Bccs/caas%3Bmaster%3Ba1466659536cf2225eadf56f43972a25e9ee1bed%22%2C%22git%3Bgit.osn.oraclecorp.com%3Bosn/cef%3Bmaster%3B749581bac1d93cda036d33fbbdbe95f7bd0987bf%22%5D%7D&json2=%7B%22cspec_deps%22%3A%5B%22git%3Bgit.osn.oraclecorp.com%3Bccs/caas%3Bmaster%3Ba1466659536cf2225eadf56f43972a25e9ee1bed%22%2C%22git%3Bgit.osn.oraclecorp.com%3Bosn/cef%3Bmaster%3B749581bac1d93cda036d33fbbdbe95f7bd0987bf%22%5D%2C%22cspec%22%3A%22git%3Bgit.osn.oraclecorp.com%3Bosn/cec-server-integration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%7D", %Q[{ "cspec": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64", "cspec_deps": [ "git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed", "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"] }], %Q[{ "cspec_deps": [ "git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed", "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"], "cspec": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"}])

                                z = ""
                                Json_change_tracker.examples_by_op.values.each do | example |
                                        z << example
                                end
                                Json_change_tracker.usage_full_examples = z
                                STDOUT.sync     # always flush immediately
                                STDERR.sync     # always flush immediately
                        end
                        Json_change_tracker.initialized = true
                end
                def init_example_for_op(op, url_example, json1_example, json2_example)
                        url_example.sub!('@WEB_ROOT@', Json_change_tracker.web_root)
                        
                        json1_obj = JSON.parse(json1_example)
                        pretty_printed_json1_example = JSON.pretty_generate(json1_obj)
                        
                        json2_obj = JSON.parse(json2_example)
                        pretty_printed_json2_example = JSON.pretty_generate(json2_obj)
                        
                        z = "<h4>#{op} operation:</h4>"
                        z << "<h5>Example URL:</h5><a href='#{url_example}'>#{url_example}</a>\n"
                        z << "<h5>Example JSON descrinbing the <b>starting</b> point set of commit IDs:</h5><pre>#{pretty_printed_json1_example}\n</pre>\n"
                        z << "<h5>Example JSON descrinbing the <b>ending</b> point set of commit IDs:</h5><pre>#{pretty_printed_json2_example}\n</pre>\n"
                        z
                end
                def examples(example_op=nil)
                        init
                        z = "\n<h3>Example usage:</h3>\n"
                        if !example_op || !Json_change_tracker.examples_by_op.has_key?(example_op)
                                z << Json_change_tracker.usage_full_examples
                        else
                                z << Json_change_tracker.examples_by_op[example_op]
                        end
                        z
                end
                def test_assert_result_from_json(expected_result, op, json1, json2, title)
                        http_response_code, actual_result = Json_change_tracker.new.go(op, json1, json2)
                        U.assert_eq(200, http_response_code, "#{title} HTTP response code")
                        if !title
                                title = "from #{json}"
                        end
                        U.assert_json_eq(expected_result, actual_result, title)
                end
                def assert_error_result_from_json(expected_result, op, json_input1, json_input2, expected_http_response_code, title)
                        actual_http_response_code, actual_result = Json_change_tracker.new.go(op, json_input1, json_input2)
                        
                        actual_result.gsub!(/:\d+:/, ":NNN:")
                        actual_result.gsub!(/cli_main.rb:.*/, "\n")     #       stack frame contains <main> which is confusing
                        actual_result.gsub!(/<title>.*?<\/title>/, "")  #       strip out HTML
                        actual_result.gsub!(/<h3>Error: /, "")          #       strip out HTML
                        actual_result.gsub!(/<.*?>/, "")                #       strip out HTML
                        actual_result.gsub!(/\s*$/, "")                 #       strip out extra white space
                        actual_result.gsub!(/^\s*/, "")                 #       strip out extra white space
                        actual_result.gsub!(/$/, "\n")                  #       end w/ a newline
                        actual_result.gsub!(/\n+/, "\n")                #       strip out extra white space
                        
                        U.assert_eq(expected_http_response_code, actual_http_response_code, "#{title} HTTP response code")
                        U.assert_eq(expected_result, actual_result, title)
                end
                def test_bad_json()
                        #cspec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64"
                        #cspec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"

                        assert_error_result_from_json(%Q[did not know how to interpret op 'some_nonexistent_op'To manually interact with the change tracker, visit the change tracker UI.\nExample usage:\nlist_bug_IDs_between operation:Example URL:@WEB_ROOT@/?json=%7B%20%22op%22%20%3A%20%22list_bug_IDs_between%22%2C%20%22cspec1%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%20%22cspec2%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%20%7D%20\nExample JSON:{\n"op": "list_bug_IDs_between",\n"cspec1": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64",\n"cspec1_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"\n}\nlist_changes_between operation:Example URL:@WEB_ROOT@/?json=%7B%20%20%22op%22%20%3A%20%22list_changes_between%22%2C%20%20%22cspec1%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%20%20%22cspec2%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%20%20%7D%20\nExample JSON:{\n"op": "list_changes_between",\n"cspec1": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64",\n"cspec1_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e",\n"cspec2_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n]\n}\nlist_files_changed_between operation:Example URL:@WEB_ROOT@/?json=%7B%20%22op%22%20%3A%20%22list_files_changed_between%22%2C%20%20%22cspec1%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%20%20%22cspec2%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%20%20%7D%20\nExample JSON:{\n"op": "list_files_changed_between",\n"cspec1": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64",\n"cspec1_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"\n}\n], "some_nonexistent_op", "json1 text", "json2 text", 400, "nonexistent op")

                        assert_error_result_from_json(%Q[trouble parsing "whatever": 757: unexpected token at 'whatever'To manually interact with the change tracker, visit the change tracker UI.\nExample usage:\nlist_bug_IDs_between operation:Example URL:@WEB_ROOT@/?json=%7B%20%22op%22%20%3A%20%22list_bug_IDs_between%22%2C%20%22cspec1%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%20%22cspec2%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%20%7D%20\nExample JSON:{\n"op": "list_bug_IDs_between",\n"cspec1": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64",\n"cspec1_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"\n}\nlist_changes_between operation:Example URL:@WEB_ROOT@/?json=%7B%20%20%22op%22%20%3A%20%22list_changes_between%22%2C%20%20%22cspec1%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%20%20%22cspec2%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%20%20%7D%20\nExample JSON:{\n"op": "list_changes_between",\n"cspec1": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64",\n"cspec1_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e",\n"cspec2_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n]\n}\nlist_files_changed_between operation:Example URL:@WEB_ROOT@/?json=%7B%20%22op%22%20%3A%20%22list_files_changed_between%22%2C%20%20%22cspec1%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%20%20%22cspec2%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%20%20%7D%20\nExample JSON:{\n"op": "list_files_changed_between",\n"cspec1": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64",\n"cspec1_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"\n}\n], "list_bug_IDs_between", "whatever", "whatever", 400, "ridiculous null request")
                        assert_error_result_from_json(%Q[did not find anything for key 'cspec1'To manually interact with the change tracker, visit the change tracker UI.\nExample usage:\nlist_bug_IDs_between operation:Example URL:@WEB_ROOT@/?json=%7B%20%22op%22%20%3A%20%22list_bug_IDs_between%22%2C%20%22cspec1%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%20%22cspec2%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%20%7D%20\nExample JSON:{\n"op": "list_bug_IDs_between",\n"cspec1": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64",\n"cspec1_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"\n}\n], "list_bug_IDs_between", nil, "json2 text", 400, "no cspec1")
                        assert_error_result_from_json(%Q[did not find anything for key 'cspec2'To manually interact with the change tracker, visit the change tracker UI.\nExample usage:\nlist_bug_IDs_between operation:Example URL:@WEB_ROOT@/?json=%7B%20%22op%22%20%3A%20%22list_bug_IDs_between%22%2C%20%22cspec1%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%20%22cspec2%22%20%3A%20%22git%3Bgit.osn.oraclecorp.com%3Bosn%2Fcec-server-integration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%20%7D%20\nExample JSON:{\n"op": "list_bug_IDs_between",\n"cspec1": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64",\n"cspec1_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2_deps": [\n"git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed",\n"git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"\n],\n"cspec2": "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"\n}\n], "list_bug_IDs_between", "json1 text", nil, 400, "no cspec2")
                end
                def assert_close_neighbors_result(expected, op)
                        cspec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64"
                        cspec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"

                        z1 = %Q[{ "cspec" : "#{cspec1}" }]
                        z2 = %Q[{ "cspec" : "#{cspec2}" }]
                        test_assert_result_from_json(expected, op, z1, z2, "close neighbors list changes")
                end
                def test_close_neighbors_all_ops()
                        assert_close_neighbors_result(%Q[[
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;osn/cec-server-integration;master;",
                        "commit_id": "06c85af5cfa00b0e8244d723517f8c3777d7b77e",
                        "comment": "New version com.oracle.cecs.caas:manifest:1.0.3013, initiated by https://osnci.us.oracle.com/job/caas.build.pl.master/3013/ and updated (consumed) by https://osnci.us.oracle.com/job/serverintegration.deptrigger.pl.master/485/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;osn/cec-server-integration;master;",
                        "commit_id": "22ab587dd9741430c408df1f40dbacd56c657c3f",
                        "comment": "New version com.oracle.cecs.caas:manifest:1.0.3012, initiated by https://osnci.us.oracle.com/job/caas.build.pl.master/3012/ and updated (consumed) by https://osnci.us.oracle.com/job/serverintegration.deptrigger.pl.master/484/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;osn/cec-server-integration;master;",
                        "commit_id": "7dfff5f400b3011ae2c4aafac286d408bce11504",
                        "comment": "New version com.oracle.cecs.caas:manifest:1.0.3011, initiated by https://osnci.us.oracle.com/job/caas.build.pl.master/3011/ and updated (consumed) by https://osnci.us.oracle.com/job/serverintegration.deptrigger.pl.master/483/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;ccs/caas;master;",
                        "commit_id": "a1466659536cf2225eadf56f43972a25e9ee1bed",
                        "comment": "New version com.oracle.cecs.docs-server:manifest:1.0.686, initiated by https://osnci.us.oracle.com/job/docs.build.pl.master/686/ and updated (consumed) by https://osnci.us.oracle.com/job/caas.deptrigger.pl.master/3008/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;ccs/caas;master;",
                        "commit_id": "b8563401dcd8576b14c91b7bbbd2aa23af9af406",
                        "comment": "New version com.oracle.cecs.docs-server:manifest:1.0.685, initiated by https://osnci.us.oracle.com/job/docs.build.pl.master/685/ and updated (consumed) by https://osnci.us.oracle.com/job/caas.deptrigger.pl.master/3007/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;ccs/caas;master;",
                        "commit_id": "89ce37a8745c11455366e46e509825d0ffc92489",
                        "comment": "New version com.oracle.cecs.docs-server:manifest:1.0.684, initiated by https://osnci.us.oracle.com/job/docs.build.pl.master/684/ and updated (consumed) by https://osnci.us.oracle.com/job/caas.deptrigger.pl.master/3006/"
                        }
                        ]], "list_changes_between")
                        assert_close_neighbors_result("[]", "list_bug_IDs_between")
                        assert_close_neighbors_result(%Q[{\n  "git;git.osn.oraclecorp.com;osn/cec-server-integration;master;": [\n    "component.properties",\n    "deps.gradle"\n  ],\n  "git;git.osn.oraclecorp.com;ccs/caas;master;": [\n    "component.properties",\n    "deps.gradle"\n  ]\n}], "list_files_changed_between")
                end
                def test_nonexistent_codeline()
                        cspec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integrationXXXXX;;;6b5ed0226109d443732540fee698d5d794618b64"
                        cspec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"

                        z1 = %Q[{ "cspec" : "#{cspec1}" }]
                        z2 = %Q[{ "cspec" : "#{cspec2}" }]
                        expected = %Q[Error encountered: error: bad exit code from
                        cd "/scratch/change_tracker/git/git.osn.oraclecorp.com/osn"; git clone  "git@git.osn.oraclecorp.com:osn/cec-server-integrationXXXXX.git"
                        GitLab: The project you were looking for could not be found.
                        fatal: The remote end hung up unexpectedly
                        
                        /net/slcipaq.us.oracle.com/scratch/nsproul/dp/git/change_tracker/src/u.rb:NNN:in `block in system'
                        /opt/sensu/embedded/lib/ruby/2.0.0/open3.rb:NNN:in `popen_run'
                        /opt/sensu/embedded/lib/ruby/2.0.0/open3.rb:NNN:in `popen3'
                        /net/slcipaq.us.oracle.com/scratch/nsproul/dp/git/change_tracker/src/u.rb:NNN:in `system'
                        /net/slcipaq.us.oracle.com/scratch/nsproul/dp/git/change_tracker/src/change_tracker.rb:NNN:in `codeline_disk_write'
                        /net/slcipaq.us.oracle.com/scratch/nsproul/dp/git/change_tracker/src/change_tracker.rb:NNN:in `unreliable_autodiscovery_of_dependencies_from_build_configuration'
                        /net/slcipaq.us.oracle.com/scratch/nsproul/dp/git/change_tracker/src/change_tracker.rb:NNN:in `from_spec'
                        /net/slcipaq.us.oracle.com/scratch/nsproul/dp/git/change_tracker/src/json_change_tracker.rb:NNN:in `get_Compound_commit'
                        /net/slcipaq.us.oracle.com/scratch/nsproul/dp/git/change_tracker/src/json_change_tracker.rb:NNN:in `get_Compound_commit_pair'
                        /net/slcipaq.us.oracle.com/scratch/nsproul/dp/git/change_tracker/src/json_change_tracker.rb:NNN:in `go'
                        /net/slcipaq.us.oracle.com/scratch/nsproul/dp/git/change_tracker/src/json_change_tracker.rb:NNN:in `assert_error_result_from_json'
                        /net/slcipaq.us.oracle.com/scratch/nsproul/dp/git/change_tracker/src/json_change_tracker.rb:NNN:in `test_nonexistent_codeline'
                        /net/slcipaq.us.oracle.com/scratch/nsproul/dp/git/change_tracker/src/json_change_tracker.rb:NNN:in `test'
                        ]
                        assert_error_result_from_json(expected, "list_changes_between", z1, z2, 500, "nonexistent codeline")
                end
                def test()
                        Json_change_tracker.init("http://#{Socket.gethostname}:4567")
                        test_nonexistent_codeline
                        puts "skipping test_bad_json"
                        puts "skipping test_bad_json"
                        puts "skipping test_bad_json"
                        puts "skipping test_bad_json"
                        #test_bad_json
                        test_close_neighbors_all_ops
                end
        end
end
