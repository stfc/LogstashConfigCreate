require_relative  'filters'
class CodeWriter
    attr_reader :count, :text
    attr_accessor :prefix, :suffix
    def initialize
        @indent=0
        @count = 0
        @hightlight = -1
        @text = []
        @prefix = ''
        @suffix = ''
    end
    def indent()
        @indent = @indent + 1
    end
    def unindent()
        @indent = @indent - 1
    end
    def reset()
        @hightlight = -1
    end
    def hightlight()
        @hightlight = @indent
    end
    def write(line)
        @count = @count + 1
        line = prefix + "    " * @indent + line + suffix
        if @hightlight == @indent
            line = line + "    <-------"
        end
        @text.push line
        puts line
    end
end
class Condition
    attr_accessor :tag
    def writeBegin(writer)
        if @tag && @tag != ''
            writer.write('if ("' + tag + '" in [tags]){')
            writer.indent
        end
    end
    def writeEnd(writer)
        if @tag
            writer.unindent
            writer.write("}")
        end
    end
end
class Root < Creatable
    attr_accessor :branches, :hightlight, :outputLines, :filePath
    def initialize
        @branches = []
    end
    def unhandledLines(exclude = nil)
        return @outputLines
    end
    def writeOutput()
        writer = CodeWriter.new
        writer.prefix = "###"
        writer.write('######################################################################################################################################')
        writer.write("This config file was generated by a cli")
        writer.write('')
        writer.write("It follows this structure:")
        writer.indent
        self.writeStructure(writer)
        writer.unindent
        writer.write('###############################################################################################################')
        writer.prefix = ""
        writer.write('')
        writer.write "input {"
        writer.indent
        writer.write "file {"
        writer.indent
        writer.write "path => '#{@filePath}'"
        writer.write "start_position => 'beginning'"
        writer.unindent
        writer.write "}"
        writer.unindent
        writer.write "}"
        writer.write ""
        writer.write('filter {')
        writer.indent
        for branch in @branches
            branch.writeOutput(writer)
        end
        writer.unindent
        writer.write '}'
        writer.write ""
        writer.write "output {"
        writer.indent
        writer.write "stdout {"
        writer.indent
        writer.write "codec => 'rubydebug'"
        writer.unindent
        writer.write "}"
        writer.unindent
        writer.write "}"

        return writer.text
    end
    def writeStructure(writer = nil)
        if !writer
            writer = CodeWriter.new
        end
        writer.write("")
        if @hightlight
            writer.hightlight
        end
        writer.write('{{...}}')
        writer.reset
        writer.indent
        for branch in @branches
            branch.writeStructure(writer)
        end
        writer.unindent
        writer.write("")
    end
end
class Branch < Creatable
    attr_accessor :condition, :branches, :hightlight, :creator, :parent
    attr_accessor :grok, :drop, :date, :mutate
    def initialize(parent)
        @branches = []
        @condition = Condition.new
        @grok = GrokFilter.new
        @drop = DropFilter.new
        @date = DateFilter.new
        @mutate = MutateFilter.new
        @parent = parent
    end
    def writeOutput(writer)

        @condition.tag = @grok.tag

        @grok.ifUsedWriteOutput(writer)
        @date.ifUsedWriteOutput(writer)
        @mutate.ifUsedWriteOutput(writer)
        @drop.ifUsedWriteOutput(writer)

        if @branches.count > 0
            @condition.writeBegin(writer)
            for branch in @branches
                branch.writeOutput(writer)
            end
            @condition.writeEnd(writer)
        end
    end
    def writeStructure(writer)
        if @hightlight
            writer.hightlight
        end
        count = writer.count

        @grok.ifUsedWriteStructure(writer)
        @date.ifUsedWriteStructure(writer)
        @mutate.ifUsedWriteStructure(writer)
        @drop.ifUsedWriteStructure(writer)

        if count == writer.count
            writer.write("[empty]")
        end
        writer.indent
        for branch in @branches
            branch.writeStructure(writer)
        end
        writer.unindent
        writer.reset
    end
    def outputLines
        return @parent.outputLines.map{|line| @grok.matches(line)}.map{|captures| if captures; captures["GREEDYDATA:message"] end }.compact
    end
    def unhandledLines(exclude = nil)
        return self.outputLines.reject{|line| self.handles?(line, exclude) }
    end
    def handles?(line, exclude = nil)
        for branch in @branches.reject{|x| x == exclude}
            if branch.grok.matches(line)
                return true
            end
        end
        return false
    end
end