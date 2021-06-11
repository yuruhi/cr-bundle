require "compiler/crystal/syntax"
require "compiler/crystal/tools/formatter"

module CrBundle
  class Bundler
    def initialize(@options : Options)
      @require_history = Deque(Path).new
    end

    # see: https://crystal-lang.org/reference/syntax_and_semantics/requiring_files.html
    private def get_absolute_paths(path : Path, required_from : Path) : Array(Path)?
      add_cr = path.basename.to_s + ".cr"
      if path.to_s.starts_with?(%r[\./|\.\./])
        if path.to_s.ends_with?("**")
          return Dir.glob(Path[path.to_s + "/*"].expand(required_from.parent).to_s).select { |s|
            File.file?(s)
          }.map { |s| Path[s] }.sort
        elsif path.to_s.ends_with?("*")
          return Dir.glob(path.expand(required_from.parent).to_s).select { |s|
            File.file?(s)
          }.map { |s| Path[s] }.sort
        else
          file = path.expand(required_from.parent)
          return [file] if File.file?(file)
          file = Path[path.to_s + ".cr"].expand(required_from.parent)
          return [file] if File.file?(file)
          file = (path / add_cr).expand(required_from.parent)
          return [file] if File.file?(file)
        end
      else
        if path.to_s.ends_with?("**")
          return @options.paths.flat_map { |library_path|
            Dir.glob(Path[path.to_s + "/*"].expand(library_path).to_s).select { |s|
              File.file?(s)
            }.map { |s| Path[s] }
          }.sort
        elsif path.to_s.ends_with?("*")
          return @options.paths.flat_map { |library_path|
            Dir.glob(path.expand(library_path).to_s).select { |s|
              File.file?(s)
            }.map { |s| Path[s] }
          }.sort
        else
          @options.paths.each do |library_path|
            file = path.expand(library_path)
            return [file] if File.file?(file)
            file = Path[path.to_s + ".cr"].expand(library_path)
            return [file] if File.file?(file)
            file = (path / add_cr).expand(library_path)
            return [file] if File.file?(file)
            file = (path / "src" / add_cr).expand(library_path)
            return [file] if File.file?(file)
            file = (path / "src" / path.basename / add_cr).expand(library_path)
            return [file] if File.file?(file)
          end
        end
      end
      nil
    end

    def detect_require(ast : Crystal::ASTNode) : Array({String, Crystal::Location})
      result = [] of {String, Crystal::Location}
      case ast
      when Crystal::Expressions
        ast.expressions.each do |child|
          result.concat detect_require(child)
        end
      when Crystal::Require
        result << {ast.string, ast.location.not_nil!}
      end
      result
    end

    def bundle(source : String, file_name : Path) : String
      @require_history << file_name

      parser = Crystal::Parser.new(source)
      parser.filename = file_name.to_s

      requires = detect_require(parser.parse)
      expanded_codes = requires.map do |path, location|
        if absolute_paths = get_absolute_paths(Path[path], file_name)
          <<-EXPANDED_CODE
          # require "#{path}"
          #{absolute_paths.join('\n') { |absolute_path|
              unless @require_history.includes?(absolute_path)
                bundle(File.read(absolute_path), absolute_path)
              else
                ""
              end
            }}
          EXPANDED_CODE
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
      bundled = Crystal.format(bundled, file_name.to_s) if @options.format
      bundled
    end

    def dependencies(source : String, file_name : Path) : Array(Path)
      parser = Crystal::Parser.new(source)
      parser.filename = file_name.to_s
      detect_require(parser.parse).flat_map { |path, location|
        get_absolute_paths(Path[path], file_name) || ([] of Path)
      }
    end
  end
end
