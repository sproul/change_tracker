class File_set
        attr_accessor :repo
        attr_accessor :file_list
        def initialize(repo, file_list)
                self.repo = repo
                self.file_list = file_list.sort
        end
        def to_json()
                h = Hash.new
                h[self.repo.spec] = file_list
                h.to_json
        end
        def to_s()
                self.to_json
        end
end

class File_sets
        attr_accessor :file_sets
        def initialize()
                self.file_sets = Hash.new
        end
        def add_set(file_set)
                fsrs = file_set.repo.spec
                if self.file_sets.has_key?(fsrs)
                        self.file_sets[fsrs] = (self.file_sets[fsrs] + file_set.file_list).uniq.sort
                else
                        self.file_sets[fsrs] = file_set.file_list
                end
        end
        def add_sets(other_fs)
                other_fs.file_sets.each do | set |
                        self.add_set(set)
                end
        end
        def eql?(other)
                if self.file_sets.size != other.file_sets.size
                        return false
                end
                self.file_sets.keys.each do | repo |
                        if !self.file_sets[repo].eql?(other.file_sets[repo])
                                return false
                        end
                end
                return true
        end
        def to_json()
                self.file_sets.to_json
        end
        def to_s()
                self.to_json
        end
        class << self
                TEST_REPO_NAME1 = "git;git.osn.oraclecorp.com;osn/serverintegration;"
                TEST_REPO_NAME2 = "git;git.osn.oraclecorp.com;osn/cec-else;"

                def test()
                        r1 = Repo.new(TEST_REPO_NAME1)
                        r2 = Repo.new(TEST_REPO_NAME2)
                        fs1 = File_set.new(r1, ["a", "b"])
                        fs2 = File_set.new(r1, ["a", "b"])
                        fs3 = File_set.new(r2, ["a", "z"])
                        fss1 = File_sets.new
                        fss1.add_set(fs1)
                        fss2 = File_sets.new
                        fss2.add_set(fs1)
                        U.assert_eq(fss1, fss2, "File_sets.test0")
                        fss2.add_set(fs2)
                        U.assert_eq(fss1, fss2, "File_sets.test1")
                        fss2.add_set(File_set.new(r1, ["c", "b"]))
                        U.assert_json_eq({r1.spec => ["a", "b", "c"]}, fss2, "File_sets.test2")
                        fss2.add_set(fs3)
                        U.assert_json_eq({r1.spec => ["a", "b", "c"], r2.spec => ["a", "z"]}, fss2, "File_sets.test3")
                end
        end
end
