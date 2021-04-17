module CrBundle
  class Bundler
    def initialize(@options : Options)
      @require_history = Deque(Path).new
    end

    # see: https://crystal-lang.org/reference/syntax_and_semantics/requiring_files.html
    private def get_absolute_path(path : Path, required_from : Path) : Array(Path)?
      add_cr = path.basename.to_s + ".cr"
      if path.to_s.starts_with?(%r[\./|\.\./])
        if path.to_s.ends_with?("**")
          return Dir.glob(Path[path.to_s + "/*"].expand(required_from.parent)).select { |s|
            File.file?(s)
          }.map { |s| Path[s] }.sort
        elsif path.to_s.ends_with?("*")
          return Dir.glob(path.expand(required_from.parent)).select { |s|
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
            Dir.glob(Path[path.to_s + "/*"].expand(library_path)).select { |s|
              File.file?(s)
            }.map { |s| Path[s] }
          }.sort
        elsif path.to_s.ends_with?("*")
          return @options.paths.flat_map { |library_path|
            Dir.glob(path.expand(library_path)).select { |s|
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

    def bundle(source : String, file_name : Path) : String
      @require_history << file_name
      source.gsub(/require(\s*)"(.*?)"/) do
        if file = get_absolute_path(Path[$2], file_name)
          <<-EXAPANDED_CODE
          # require "#{$2}"
          #{file.join('\n') { |file|
              unless @require_history.includes?(file)
                bundle(File.read(file), file)
              else
                ""
              end
            }}
          EXAPANDED_CODE
        else
          $~[0]
        end
      end
    end
  end
end
