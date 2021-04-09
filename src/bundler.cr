module CrBundle
  class Bundler
    def initialize(@options : Options)
    end

    # see: https://crystal-lang.org/reference/syntax_and_semantics/requiring_files.html
    private def get_absolute_path(path : Path, required_from : Path) : Path?
      if path.to_s.starts_with?(%r[\./|\.\./])
        file = path.expand(required_from.parent)
        if File.exists?(file) && File.file?(file)
          return file
        end
      else
        @options.paths.each do |library_path|
          file = path.expand(library_path)
          if File.exists?(file) && File.file?(file)
            return file
          end
        end
      end
      nil
    end

    def bundle(source : String, file_name : Path) : String
      source.gsub(/require(\s*)"(.*?)"/) {
        if file = get_absolute_path(Path[$2 + ".cr"], file_name)
          %[# require "#{$2}"\n#{bundle(File.read(file), file)}]
        else
          $~[0]
        end
      }
    end
  end
end
