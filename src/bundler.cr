module CrBundle
  class Bundler
    def initialize(@options : Options)
      @require_history = Deque(Path).new
    end

    # see: https://crystal-lang.org/reference/syntax_and_semantics/requiring_files.html
    private def get_absolute_path(path : Path, required_from : Path) : Path?
      add_cr = path.basename.to_s + ".cr"
      if path.to_s.starts_with?(%r[\./|\.\./])
        file = path.expand(required_from.parent)
        return file if File.file?(file)
        file = Path[path.to_s + ".cr"].expand(required_from.parent)
        return file if File.file?(file)
        file = (path / add_cr).expand(required_from.parent)
        return file if File.file?(file)
      else
        @options.paths.each do |library_path|
          file = path.expand(library_path)
          return file if File.file?(file)
          file = Path[path.to_s + ".cr"].expand(library_path)
          return file if File.file?(file)
          file = (path / add_cr).expand(library_path)
          return file if File.file?(file)
          file = (path / "src" / add_cr).expand(library_path)
          return file if File.file?(file)
          file = (path / "src" / path.basename / add_cr).expand(library_path)
          return file if File.file?(file)
        end
      end
      nil
    end

    def bundle(source : String, file_name : Path) : String
      @require_history << file_name
      source.gsub(/require(\s*)"(.*?)"/) do
        file = get_absolute_path(Path[$2], file_name)
        required = file && @require_history.includes?(file)
        if file && !required
          <<-EXPANDED_SOURCE
          # require "#{$2}"
          #{bundle(File.read(file), file)}
          EXPANDED_SOURCE
        elsif required
          ""
        else
          $~[0]
        end
      end
    end
  end
end
