require "compiler/crystal/syntax"
require "compiler/crystal/formatter"

module CrBundle
  class Bundler
    def initialize(@options : Options)
      @require_history = Set(String).new
    end

    private macro check_path(path)
      %path = ({{path}}).to_s
      %path += ".cr" unless %path.ends_with?(".cr")
      return File.expand_path(%path) if File.exists?(%path)
    end

    private def collect_files(dir : String, rec : Bool) : Array(String)
      files = [] of String
      Dir.each_child(dir) do |file|
        file = "#{dir}/#{file}"
        if File.directory?(file)
          files.concat collect_files(file, rec) if rec
        else
          files.push file if file.ends_with?(".cr")
        end
      end
      files
    end

    # see: https://crystal-lang.org/reference/syntax_and_semantics/requiring_files.html
    private def find_path(path : String, relative_to : String) : String | Array(String) | Nil
      is_relative = path.starts_with?(".")
      includes_slash = path.includes?('/')
      relative_path = Path[relative_to] / path
      if path.ends_with?(".cr")
        check_path relative_path
      elsif (rec = path.ends_with?("/**")) || path.ends_with?("/*")
        return collect_files(relative_path.dirname, rec)
      elsif !is_relative && !includes_slash
        check_path relative_path
        check_path relative_path / path
        check_path relative_path / "src" / path
        check_path relative_path / "src" / path / path
      elsif !is_relative && includes_slash
        before, after = path.split('/', 2)
        check_path relative_path
        check_path relative_path / relative_path.basename
        check_path Path[relative_to] / before / "src" / after
        check_path Path[relative_to] / before / "src" / after / relative_path.basename
      elsif is_relative && !includes_slash
        check_path relative_path
        check_path relative_path / relative_path.basename
      else # if is_relative && includes_slash
        check_path relative_path
        check_path relative_path / relative_path.basename
      end
      return nil
    end

    private def get_absolute_paths(path : String, required_from : String) : Array(String)?
      result = if path.to_s.starts_with?('.')
                 find_path(path, File.dirname(required_from))
               else
                 @options.paths.flat_map { |relative_to| find_path(path, relative_to) || Array(String).new }
               end
      (
        case result
        when String
          [result]
        when Array(String)
          result.empty? ? nil : result
        end
      ).try &.map { |file| File.expand_path(file) }
    end

    private def detect_requires(ast : Crystal::ASTNode) : Array({String, Crystal::Location})
      result = [] of {String, Crystal::Location}
      case ast
      when Crystal::Expressions
        ast.expressions.each do |child|
          result.concat detect_requires(child)
        end
      when Crystal::Require
        result << {ast.string, ast.location.not_nil!}
      end
      result
    end

    def bundle(source : String, file_name : String) : String
      @require_history << file_name

      parser = Crystal::Parser.new(source)
      parser.filename = file_name.to_s

      requires = detect_requires(parser.parse)
      expanded_codes = requires.map do |path, location|
        if absolute_paths = get_absolute_paths(path, file_name)
          expanded = String::Builder.new
          expanded << %[# require "#{path}"\n]
          absolute_paths.sort.each_with_index do |absolute_path, i|
            expanded << '\n' if i > 0
            unless @require_history.includes?(absolute_path)
              expanded << bundle(File.read(absolute_path), absolute_path)
            end
          end
          expanded.to_s
        else
          %[require "#{path}"]
        end
      end

      lines = source.lines
      requires.zip(expanded_codes).sort_by do |(path, location), expanded|
        location
      end.reverse_each do |(path, location), expanded|
        string = lines[location.line_number - 1]
        start_index = location.column_number - 1
        end_index = string[start_index..].match(/require\s*".*?"/).not_nil!.end.not_nil! + start_index
        lines[location.line_number - 1] = string.sub(start_index...end_index, expanded)
      end
      bundled = lines.join('\n')
      @options.format ? Crystal.format(bundled, file_name.to_s) : bundled
    end

    def dependencies(source : String, file_name : String) : Array(String)
      parser = Crystal::Parser.new(source)
      parser.filename = file_name.to_s
      detect_requires(parser.parse).flat_map do |path, location|
        get_absolute_paths(path, file_name) || Array(String).new
      end
    end
  end
end
