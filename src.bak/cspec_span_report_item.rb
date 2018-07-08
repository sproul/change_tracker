class Cspec_span_report_item
        OUTPUT_STYLE_TERSE = "terse"
        OUTPUT_STYLE_NORMAL = "normal"
        OUTPUT_STYLE_EXPANDED = "expanded"

        attr_accessor :cspec1
        attr_accessor :cspec2
        attr_accessor :item

        def initialize(cspec1, cspec2, item)
                self.cspec1 = cspec1
                self.cspec2 = cspec2
                self.item = item
        end
        def to_s()
                if !self.item.respond_to?(:each)
                        return "Cspec_span_report_item(#{self.item})"
                end
                z = "Cspec_span_report_item("
                self.item.each do | item_elt |
                        z << "\n" << item_elt.to_s
                end
                z << "\n)\n"
                z
        end
        def eql?(other)
                if !self.cspec1.eql?(other.cspec1) || !self.cspec2.eql?(other.cspec2)
                        puts "cspec no"
                        return false
                end
                if self.item.respond_to?(:length) && other.item.respond_to?(:length)
                        if self.item.length != other.item.length
                                puts "len no"
                                return false
                        end
                        0.upto(self.item.length-1) do |j|
                                if !self.item[j].eql?(other.item[j])
                                        puts "itehm #{j} no"
                                        return false
                                end
                        end
                        return true
                end
                puts "defering to item eql...#{self.item.eql?(other.item)}"
                return self.item.eql?(other.item)
        end
        def to_jsonable_h(output_style=OUTPUT_STYLE_TERSE)
                case output_style
                when OUTPUT_STYLE_TERSE
                        self.item.to_json
                when OUTPUT_STYLE_NORMAL
                        h = Hash.new
                        h["cspec1"] = self.cspec1.repo_and_commit_id
                        h["cspec2"] = self.cspec2.repo_and_commit_id
                        h["output"] = self.item
                        h
                when OUTPUT_STYLE_EXPANDED
                        h = Hash.new
                        h["cspec1"] = self.cspec1.to_jsonable_h
                        h["cspec2"] = self.cspec2.to_jsonable_h
                        h["output"] = self.item
                        h
                else
                        raise "unexpected output_style #{output_style}"
                end
        end
end

class Cspec_span_report_item_set
        attr_accessor :items

        def initialize()
                self.items = []
        end
        def eql?(other)
                if items.length != other.items.length
                        puts "set len noo"
                        return false
                end
                0.upto(self.items.length-1) do |j|
                        if !self.items[j].eql?(other.items[j])
                                puts "set itehm #{j} no"
                                return false
                        end
                end
                return true
        end
        def add(item)
                if !item.is_a?(Cspec_span_report_item)
                        puts "Bad type arg handed to Cspec_span_report_item_set (expecting Cspec_span_report_item only)..."
                        pp item
                        raise "Cspec_span_report_item_set.add(#{item}) but should only be Cspec_span_report_item"
                end
                self.items << item
        end
        def all_items()
                all = []
                items.each do | report_item |
                        all = all.concat(report_item.item)
                end
                all
        end
        def prettify_json(json)
                z = JSON.parse(json)
                JSON.pretty_generate(z)
        end
        def to_json()
                output_style = Cspec_span_report_item_set.output_style
                pretty = Cspec_span_report_item_set.pretty
                if !output_style
                        output_style = Cspec_span_report_item::OUTPUT_STYLE_TERSE
                end
                case output_style
                when Cspec_span_report_item::OUTPUT_STYLE_TERSE
                        json_output = self.all_items.to_json
                when Cspec_span_report_item::OUTPUT_STYLE_NORMAL, Cspec_span_report_item::OUTPUT_STYLE_EXPANDED
                        jsonable_items = []
                        self.items.each do | report_item |
                                jsonable_items << report_item.to_jsonable_h(output_style)
                        end
                        json_output = jsonable_items.to_json
                else
                        raise "unexpected output_style #{output_style}"
                end
                if pretty
                        json_output = prettify_json(json_output)
                end
                json_output
        end
        def to_s()
                self.to_json
        end
        class << self
                attr_accessor :output_style
                attr_accessor :pretty
        end
end
