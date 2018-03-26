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
                z << "<p>See the <a href=doc.htm                target='_blank'>Change Tracker doc</a> for information and examples of valid inputs."
                z << "<p>See the <a href=samples/index.html     target='_blank'>Change Tracker sample page</a> for information and examples of CT client code."
                z
        end
        def go(op, cspec_set1, cspec_set2, pretty=false)
                if !op
                        return 400, usage("op is a required argument")
                end
                if !cspec_set1
                        return 400, usage("cspec_set1 is a required argument")
                end
                if !cspec_set2
                        return 400, usage("cspec_set2 is a required argument")
                end
                http_response_code = 200
                self.op = op

                begin
                        cc1 = Cspec_set.from_s(cspec_set1, 'cspec_set1')
                        cc2 = Cspec_set.from_s(cspec_set2, 'cspec_set2')
                rescue Error_record => e_obj
                        return e_obj.http_response_code, system_error(e_obj.emsg)
                rescue RuntimeError => re
                        return 400, system_error(re.to_s + "\n" + re.backtrace.join("\n"))
                end
                json_output = nil
                begin
                        case self.op
                        when "list_bug_IDs_between"
                                x = cc2.list_bug_IDs_since(cc1)
                        when "list_changes_between"
                                x = cc2.list_changes_since(cc1)
                        when "list_files_changed_between"
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
                def init(web_root=nil)
                        if !Json_change_tracker.web_root
                                if web_root
                                        Json_change_tracker.web_root = web_root
                                else
                                        Json_change_tracker.web_root = "http://#{Socket.gethostname}:4567"
                                end
                        end
                        if !Json_change_tracker.examples_by_op
                                Json_change_tracker.examples_by_op = Hash.new
                                Json_change_tracker.examples_by_op["list_bug_IDs_between"] = init_example_for_op("list_bug_IDs_between", "@WEB_ROOT@/?pretty=true&op=list_bug_IDs_between&cspec_set1=%7B%22cspec%22%3A%22git%3Bgit.osn.oraclecorp.com%3Bosn/serverintegration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%22cspec_deps%22%3A%5B%22git%3Bgit.osn.oraclecorp.com%3Bccs/caas%3Bmaster%3Ba1466659536cf2225eadf56f43972a25e9ee1bed%22%2C%22git%3Bgit.osn.oraclecorp.com%3Bosn/cef%3Bmaster%3B749581bac1d93cda036d33fbbdbe95f7bd0987bf%22%5D%7D&cspec_set2=%7B%22cspec_deps%22%3A%5B%22git%3Bgit.osn.oraclecorp.com%3Bccs/caas%3Bmaster%3Ba1466659536cf2225eadf56f43972a25e9ee1bed%22%2C%22git%3Bgit.osn.oraclecorp.com%3Bosn/cef%3Bmaster%3B749581bac1d93cda036d33fbbdbe95f7bd0987bf%22%5D%2C%22cspec%22%3A%22git%3Bgit.osn.oraclecorp.com%3Bosn/serverintegration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%7D", %Q[{ "cspec": "git;git.osn.oraclecorp.com;osn/serverintegration;;6b5ed0226109d443732540fee698d5d794618b64", "cspec_deps": [ "git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed", "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"] }], %Q[{ "cspec_deps": [ "git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed", "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"], "cspec": "git;git.osn.oraclecorp.com;osn/serverintegration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"}])

                                Json_change_tracker.examples_by_op["list_changes_between"] = init_example_for_op("list_changes_between", "@WEB_ROOT@/?pretty=true&op=list_changes_between&cspec_set1=%7B%22cspec%22%3A%22git%3Bgit.osn.oraclecorp.com%3Bosn/serverintegration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%22cspec_deps%22%3A%5B%22git%3Bgit.osn.oraclecorp.com%3Bccs/caas%3Bmaster%3Ba1466659536cf2225eadf56f43972a25e9ee1bed%22%2C%22git%3Bgit.osn.oraclecorp.com%3Bosn/cef%3Bmaster%3B749581bac1d93cda036d33fbbdbe95f7bd0987bf%22%5D%7D&cspec_set2=%7B%22cspec_deps%22%3A%5B%22git%3Bgit.osn.oraclecorp.com%3Bccs/caas%3Bmaster%3Ba1466659536cf2225eadf56f43972a25e9ee1bed%22%2C%22git%3Bgit.osn.oraclecorp.com%3Bosn/cef%3Bmaster%3B749581bac1d93cda036d33fbbdbe95f7bd0987bf%22%5D%2C%22cspec%22%3A%22git%3Bgit.osn.oraclecorp.com%3Bosn/serverintegration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%7D", %Q[{ "cspec": "git;git.osn.oraclecorp.com;osn/serverintegration;;6b5ed0226109d443732540fee698d5d794618b64", "cspec_deps": [ "git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed", "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"] }], %Q[{ "cspec_deps": [ "git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed", "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"], "cspec": "git;git.osn.oraclecorp.com;osn/serverintegration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"}])

                                Json_change_tracker.examples_by_op["list_files_changed_between"] = init_example_for_op("list_files_changed_between", "@WEB_ROOT@/?pretty=true&op=list_files_changed_between&cspec_set1=%7B%22cspec%22%3A%22git%3Bgit.osn.oraclecorp.com%3Bosn/serverintegration%3B%3B%3B6b5ed0226109d443732540fee698d5d794618b64%22%2C%22cspec_deps%22%3A%5B%22git%3Bgit.osn.oraclecorp.com%3Bccs/caas%3Bmaster%3Ba1466659536cf2225eadf56f43972a25e9ee1bed%22%2C%22git%3Bgit.osn.oraclecorp.com%3Bosn/cef%3Bmaster%3B749581bac1d93cda036d33fbbdbe95f7bd0987bf%22%5D%7D&cspec_set2=%7B%22cspec_deps%22%3A%5B%22git%3Bgit.osn.oraclecorp.com%3Bccs/caas%3Bmaster%3Ba1466659536cf2225eadf56f43972a25e9ee1bed%22%2C%22git%3Bgit.osn.oraclecorp.com%3Bosn/cef%3Bmaster%3B749581bac1d93cda036d33fbbdbe95f7bd0987bf%22%5D%2C%22cspec%22%3A%22git%3Bgit.osn.oraclecorp.com%3Bosn/serverintegration%3B%3B%3B06c85af5cfa00b0e8244d723517f8c3777d7b77e%22%7D", %Q[{ "cspec": "git;git.osn.oraclecorp.com;osn/serverintegration;;6b5ed0226109d443732540fee698d5d794618b64", "cspec_deps": [ "git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed", "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"] }], %Q[{ "cspec_deps": [ "git;git.osn.oraclecorp.com;ccs/caas;master;a1466659536cf2225eadf56f43972a25e9ee1bed", "git;git.osn.oraclecorp.com;osn/cef;master;749581bac1d93cda036d33fbbdbe95f7bd0987bf"], "cspec": "git;git.osn.oraclecorp.com;osn/serverintegration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"}])

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
                def sub_for_vars(s)
                        s.gsub('@WEB_ROOT@', Json_change_tracker.web_root)
                end
                def init_example_for_op(op, url_example, cspec_set1_example, cspec_set2_example)
                        url_example = Json_change_tracker.sub_for_vars(url_example)

                        cspec_set1_obj = JSON.parse(cspec_set1_example)
                        pretty_printed_cspec_set1_example = JSON.pretty_generate(cspec_set1_obj)

                        cspec_set2_obj = JSON.parse(cspec_set2_example)
                        pretty_printed_cspec_set2_example = JSON.pretty_generate(cspec_set2_obj)

                        z = "<h4>#{op} operation:</h4>"
                        z << "<h5>Example URL:</h5><a href='#{url_example}'>#{url_example}</a>\n"
                        z << "<h5>Example JSON describing the <b>starting</b> point set of commit IDs:</h5><pre>#{pretty_printed_cspec_set1_example}\n</pre>\n"
                        z << "<h5>Example JSON describing the <b>ending</b> point set of commit IDs:</h5><pre>#{pretty_printed_cspec_set2_example}\n</pre>\n"
                        z
                end
                def examples(example_op=nil)
                        z = "\n<h3>Example usage:</h3>\n"
                        if !example_op || !Json_change_tracker.examples_by_op.has_key?(example_op)
                                z << Json_change_tracker.usage_full_examples
                        else
                                z << Json_change_tracker.examples_by_op[example_op]
                        end
                        z
                end
                def test_assert_result_from_s(expected_result, op, cspec_set1, cspec_set2, title)
                        http_response_code, actual_result = Json_change_tracker.new.go(op, cspec_set1, cspec_set2)
                        U.assert_eq(200, http_response_code, "#{title} HTTP response code to #{op}")
                        U.assert_json_eq_f(actual_result, "#{title} for #{op}")
                end
                def assert_error_result_from_s(expected_portion, op, json_input1, json_input2, expected_http_response_code, title)
                        actual_http_response_code, actual_result = Json_change_tracker.new.go(op, json_input1, json_input2)
                        U.assert_eq(expected_http_response_code, actual_http_response_code, "#{title} HTTP response code")
                        if !actual_result.include?(expected_portion)
                                U.assert_eq("[portion in...] #{expected_portion}", actual_result, title)
                        end
                end
                def test_bad_json()
                        cspec1 = "git;git.osn.oraclecorp.com;osn/serverintegration;;6b5ed0226109d443732540fee698d5d794618b64"
                        cspec2 = "git;git.osn.oraclecorp.com;osn/serverintegration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"

                        z1 = %Q[{ "cspec" : "#{cspec1}" }]
                        z2 = %Q[{ "cspec" : "#{cspec2}" }]

                        assert_error_result_from_s("did not know how to interpret op 'some_nonexistent_op'", "some_nonexistent_op", z1, z2, 400, "nonexistent op")
                        assert_error_result_from_s("cspec_set1 is a required argument", "list_bug_IDs_between", nil, z2, 400, "ridiculous null request")
                        assert_error_result_from_s(%Q[expecting JSON, but I see no hash], "list_bug_IDs_between", "", z2, 400, "empty cspec1")
                        assert_error_result_from_s(%Q[cspec_set2 is a required argument], "list_bug_IDs_between", z1, nil, 400, "nil cspec2")
                end
                def assert_close_neighbors_result(expected, op)
                        cspec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;6b5ed0226109d443732540fee698d5d794618b64+"
                        cspec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;06c85af5cfa00b0e8244d723517f8c3777d7b77e+"

                        z1 = %Q[{ "cspec" : "#{cspec1}" }]
                        z2 = %Q[{ "cspec" : "#{cspec2}" }]
                        test_assert_result_from_s(expected, op, z1, z2, "close neighbors list changes")
                end
                def test_close_neighbors_all_ops()
                        assert_close_neighbors_result(%Q[[
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;osn/cec-server-integration;master",
                        "commit_id": "06c85af5cfa00b0e8244d723517f8c3777d7b77e",
                        "comment": "New version com.oracle.cecs.caas:manifest:1.0.3013, initiated by https://osnci.us.oracle.com/job/caas.build.pl.master/3013/ and updated (consumed) by https://osnci.us.oracle.com/job/serverintegration.deptrigger.pl.master/485/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;osn/cec-server-integration;master",
                        "commit_id": "22ab587dd9741430c408df1f40dbacd56c657c3f",
                        "comment": "New version com.oracle.cecs.caas:manifest:1.0.3012, initiated by https://osnci.us.oracle.com/job/caas.build.pl.master/3012/ and updated (consumed) by https://osnci.us.oracle.com/job/serverintegration.deptrigger.pl.master/484/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;osn/serverintegration;master",
                        "commit_id": "7dfff5f400b3011ae2c4aafac286d408bce11504",
                        "comment": "New version com.oracle.cecs.caas:manifest:1.0.3011, initiated by https://osnci.us.oracle.com/job/caas.build.pl.master/3011/ and updated (consumed) by https://osnci.us.oracle.com/job/serverintegration.deptrigger.pl.master/483/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;ccs/caas;master",
                        "commit_id": "a1466659536cf2225eadf56f43972a25e9ee1bed",
                        "comment": "New version com.oracle.cecs.docs-server:manifest:1.0.686, initiated by https://osnci.us.oracle.com/job/docs.build.pl.master/686/ and updated (consumed) by https://osnci.us.oracle.com/job/caas.deptrigger.pl.master/3008/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;ccs/caas;master",
                        "commit_id": "b8563401dcd8576b14c91b7bbbd2aa23af9af406",
                        "comment": "New version com.oracle.cecs.docs-server:manifest:1.0.685, initiated by https://osnci.us.oracle.com/job/docs.build.pl.master/685/ and updated (consumed) by https://osnci.us.oracle.com/job/caas.deptrigger.pl.master/3007/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;ccs/caas;master",
                        "commit_id": "89ce37a8745c11455366e46e509825d0ffc92489",
                        "comment": "New version com.oracle.cecs.docs-server:manifest:1.0.684, initiated by https://osnci.us.oracle.com/job/docs.build.pl.master/684/ and updated (consumed) by https://osnci.us.oracle.com/job/caas.deptrigger.pl.master/3006/"
                        }
                        ]], "list_changes_between")
                        assert_close_neighbors_result("[]", "list_bug_IDs_between")
                        assert_close_neighbors_result(%Q[{\n  "git;git.osn.oraclecorp.com;osn/serverintegration;master": [\n    "component.properties",\n    "deps.gradle"\n  ],\n  "git;git.osn.oraclecorp.com;ccs/caas;master": [\n    "component.properties",\n    "deps.gradle"\n  ]\n}], "list_files_changed_between")
                end
                def assert_close_neighbors_cspec_by_http(expected, op)
                        z1 = "#{Json_change_tracker.web_root}/test_cspec_set1.json"
                        z2 = "#{Json_change_tracker.web_root}/test_cspec_set2.json"
                        test_assert_result_from_s(expected, op, z1, z2, "close neighbors list changes by http")
                end
                def test_cspec_by_http_for_all_ops()
                        assert_close_neighbors_cspec_by_http(%Q[[
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;osn/serverintegration;master",
                        "commit_id": "06c85af5cfa00b0e8244d723517f8c3777d7b77e",
                        "comment": "New version com.oracle.cecs.caas:manifest:1.0.3013, initiated by https://osnci.us.oracle.com/job/caas.build.pl.master/3013/ and updated (consumed) by https://osnci.us.oracle.com/job/serverintegration.deptrigger.pl.master/485/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;osn/serverintegration;master",
                        "commit_id": "22ab587dd9741430c408df1f40dbacd56c657c3f",
                        "comment": "New version com.oracle.cecs.caas:manifest:1.0.3012, initiated by https://osnci.us.oracle.com/job/caas.build.pl.master/3012/ and updated (consumed) by https://osnci.us.oracle.com/job/serverintegration.deptrigger.pl.master/484/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;osn/serverintegration;master",
                        "commit_id": "7dfff5f400b3011ae2c4aafac286d408bce11504",
                        "comment": "New version com.oracle.cecs.caas:manifest:1.0.3011, initiated by https://osnci.us.oracle.com/job/caas.build.pl.master/3011/ and updated (consumed) by https://osnci.us.oracle.com/job/serverintegration.deptrigger.pl.master/483/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;ccs/caas;master",
                        "commit_id": "a1466659536cf2225eadf56f43972a25e9ee1bed",
                        "comment": "New version com.oracle.cecs.docs-server:manifest:1.0.686, initiated by https://osnci.us.oracle.com/job/docs.build.pl.master/686/ and updated (consumed) by https://osnci.us.oracle.com/job/caas.deptrigger.pl.master/3008/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;ccs/caas;master",
                        "commit_id": "b8563401dcd8576b14c91b7bbbd2aa23af9af406",
                        "comment": "New version com.oracle.cecs.docs-server:manifest:1.0.685, initiated by https://osnci.us.oracle.com/job/docs.build.pl.master/685/ and updated (consumed) by https://osnci.us.oracle.com/job/caas.deptrigger.pl.master/3007/"
                        },
                        {
                        "repo_spec": "git;git.osn.oraclecorp.com;ccs/caas;master",
                        "commit_id": "89ce37a8745c11455366e46e509825d0ffc92489",
                        "comment": "New version com.oracle.cecs.docs-server:manifest:1.0.684, initiated by https://osnci.us.oracle.com/job/docs.build.pl.master/684/ and updated (consumed) by https://osnci.us.oracle.com/job/caas.deptrigger.pl.master/3006/"
                        }
                        ]], "list_changes_between")
                        assert_close_neighbors_cspec_by_http("[]", "list_bug_IDs_between")
                        assert_close_neighbors_cspec_by_http(%Q[{\n  "git;git.osn.oraclecorp.com;osn/serverintegration;master": [\n    "component.properties",\n    "deps.gradle"\n  ],\n  "git;git.osn.oraclecorp.com;ccs/caas;master": [\n    "component.properties",\n    "deps.gradle"\n  ]\n}], "list_files_changed_between")
                end
                def test_nonexistent_codeline()
                        cspec1 = "git;git.osn.oraclecorp.com;osn/serverintegrationXXXXX;;6b5ed0226109d443732540fee698d5d794618b64"
                        cspec2 = "git;git.osn.oraclecorp.com;osn/serverintegrationXXXXX;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"

                        z1 = %Q[{ "cspec" : "#{cspec1}" }]
                        z2 = %Q[{ "cspec" : "#{cspec2}" }]
                        assert_error_result_from_s(%Q[GitLab: The project you were looking for could not be found.], "list_changes_between", z1, z2, 500, "nonexistent codeline")
                end
                def test()
                        Json_change_tracker.init()
                        test_bad_json
                        test_cspec_by_http_for_all_ops
                        test_nonexistent_codeline
                        test_close_neighbors_all_ops
                end
                def local_url(path)
                        "#{Json_change_tracker.web_root}#{path}"
                end
                def load_local(path)
                        fn = "#{U.initial_working_directory}/public/#{path}"
                        Json_change_tracker.sub_for_vars(IO.read(fn))
                end
        end
end
