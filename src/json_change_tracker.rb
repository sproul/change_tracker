require_relative 'u'
require_relative 'change_tracker'
require 'json'

class Json_change_tracker
        class << self
                attr_accessor :examples_by_op
                attr_accessor :op
                attr_accessor :usage_full_examples
                def init()
                        Json_change_tracker.examples_by_op = Hash.new
                        Json_change_tracker.examples_by_op["list_bug_IDs_between"] = "@@ example of list_bug_IDs_between"
                        Json_change_tracker.examples_by_op["list_changes_between"] = "@@ example of list_changes_between"
                        Json_change_tracker.examples_by_op["list_files_changed_between"] = "@@ example of list_files_changed_between"
                        
                        z = ""
                        Json_change_tracker.examples_by_op.values.each do | example |
                                z << example << "\n"
                        end
                        Json_change_tracker.usage_full_examples = z
                end
                Json_change_tracker.init()
                def get(h, key)
                        if !h.has_key?(key)
                                raise "did not find anything for key '#{key}'"
                        end
                        h[key]
                end
                def get_Compound_commit(h, cspec_key)
                        cspec = get(h, cspec_key)
                        deps_key = "#{cspec_key}_deps"
                        if !h.has_key?(deps_key)
                                deps = nil
                        else
                                array_of_dep_cspec = h[deps_key]
                                deps = []
                                array_of_dep_cspec.each do | dep_cspec |
                                        deps << Git_commit.from_spec(dep_cspec)
                                end
                        end
                        Compound_commit.new(cspec, deps)
                end
                def get_Compound_commit_pair(h)
                        cc1 = get_Compound_commit(h, "cspec1")
                        cc2 = get_Compound_commit(h, "cspec2")
                        return cc1, cc2
                end
                def usage(emsg)
                        z = ''
                        z << emsg << "\n"
                        z << "Example usage:\n"
                        if Json_change_tracker.op && Json_change_tracker.examples_by_op.has_key?(Json_change_tracker.op)
                                z << Json_change_tracker.examples_by_op[Json_change_tracker.op] << "\n"
                        else
                                z << Json_change_tracker.usage_full_examples
                        end
                        z
                end
                def go(json_text)
                        begin
                                Json_change_tracker.op = nil    # in case the parse fails...
                                h = JSON.parse(json_text)
                                Json_change_tracker.op = get(h, "op")
                                case Json_change_tracker.op
                                when "list_bug_IDs_between"
                                        cc1, cc2 = get_Compound_commit_pair(h)
                                        x = cc2.list_bug_IDs_since(cc1)
                                when "list_changes_between"
                                        cc1, cc2 = get_Compound_commit_pair(h)
                                        x = cc2.list_changes_since(cc1)
                                when "list_files_changed_between"
                                        cc1, cc2 = get_Compound_commit_pair(h)
                                        x = cc2.list_files_changed_since(cc1)
                                else
                                        raise "did not know how to interpret op '#{op}'"
                                end
                                x.json
                        rescue Object => emsg_object
                                usage(emsg_object.to_s)
                        end
                end
                def test_assert_result_from_json(json, expected_result, title=nil)
                        actual_result = go(json)
                        if !title
                                title = "from #{json}"
                        end
                        U.assert_eq(expected_result, actual_result, title)
                end
                def test_bad_json()
                        cspec1 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;6b5ed0226109d443732540fee698d5d794618b64"
                        #cspec2 = "git;git.osn.oraclecorp.com;osn/cec-server-integration;;;06c85af5cfa00b0e8244d723517f8c3777d7b77e"

                        test_assert_result_from_json(%Q[{ "op" : "some_nonexistent_op" }], "did not know how to interpret op 'some_nonexistent_op'\nExample usage:\n#{Json_change_tracker.usage_full_examples}", "nonexistent op")
                        test_assert_result_from_json("whatever", "757: unexpected token at 'whatever'\nExample usage:\n#{Json_change_tracker.usage_full_examples}", "ridiculous null request")
                        test_assert_result_from_json(%Q[{ "op" : "list_bug_IDs_between" }], "did not find anything for key 'cspec1'\nExample usage:\n@@ example of list_bug_IDs_between\n", "no cspec1")
                        test_assert_result_from_json(%Q[{ "op" : "list_bug_IDs_between", "cspec1" : "#{cspec1}" }], "did not find anything for key 'cspec2'\nExample usage:\n@@ example of list_bug_IDs_between\n", "no cspec2")
                        test_assert_result_from_json(%Q[{ "op" : "list_changes_between" }], "did not find anything for key 'cspec1'\nExample usage:\n@@ example of list_changes_between\n", "no cspec1 1")
                        test_assert_result_from_json(%Q[{ "op" : "list_changes_between", "cspec1" : "#{cspec1}" }], "did not find anything for key 'cspec2'\nExample usage:\n@@ example of list_changes_between\n", "no cspec2 3")
                        test_assert_result_from_json(%Q[{ "op" : "list_files_changed_between" }], "did not find anything for key 'cspec1'\nExample usage:\n@@ example of list_files_changed_between\n", "no cspec1 3")
                        test_assert_result_from_json(%Q[{ "op" : "list_files_changed_between", "cspec1" : "#{cspec1}" }], "did not find anything for key 'cspec2'\nExample usage:\n@@ example of list_files_changed_between\n", "no cspec2 4")
                end
                def test()
                        test_bad_json
                end
        end
end
