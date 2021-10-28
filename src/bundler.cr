require "compiler/crystal/syntax"
require "compiler/crystal/formatter"

module CrBundle
  # see: https://crystal-lang.org/reference/syntax_and_semantics/requiring_files.html
  module Path
    extend self

    def find(path : String, required_from : String, require_paths : Array(String)) : Array(String)?
      paths =
        if path.starts_with?('.')
          find_in_path_relative_to_dir(path, File.dirname(required_from))
        else
          require_paths.flat_map do |relative_to|
            find_in_path_relative_to_dir(path, relative_to) || Array(String).new
          end
        end

      case paths
      when String
        [paths]
      when Array(String)
        paths.empty? ? nil : paths
      end.try &.map { |file| File.expand_path(file) }
    end

    # Copied from: https://github.com/crystal-lang/crystal/blob/1.2.0/src/compiler/crystal/crystal_path.cr
    private def find_in_path_relative_to_dir(filename, relative_to)
      return unless relative_to.is_a?(String)

      # Check if it's a wildcard.
      if filename.ends_with?("/*") || (recursive = filename.ends_with?("/**"))
        filename_dir_index = filename.rindex('/').not_nil!
        filename_dir = filename[0..filename_dir_index]
        relative_dir = "#{relative_to}/#{filename_dir}"
        if File.exists?(relative_dir)
          files = [] of String
          gather_dir_files(relative_dir, files, recursive)
          return files
        end

        return nil
      end

      each_file_expansion(filename, relative_to) do |path|
        absolute_path = File.expand_path(path)
        return absolute_path if File.exists?(absolute_path)
      end

      nil
    end

    private def each_file_expansion(filename, relative_to, &)
      relative_filename = "#{relative_to}/#{filename}"
      # Check if .cr file exists.
      yield relative_filename.ends_with?(".cr") ? relative_filename : "#{relative_filename}.cr"

      filename_is_relative = filename.starts_with?('.')

      shard_name, _, shard_path = filename.partition("/")
      shard_path = shard_path.presence

      if !filename_is_relative && shard_path
        shard_src = "#{relative_to}/#{shard_name}/src"

        # If it's "foo/bar/baz", check if "foo/src/bar/baz.cr" exists (for a shard, non-namespaced structure)
        yield "#{shard_src}/#{shard_path}.cr"

        # Then check if "foo/src/foo/bar/baz.cr" exists (for a shard, namespaced structure)
        yield "#{shard_src}/#{shard_name}/#{shard_path}.cr"

        # If it's "foo/bar/baz", check if "foo/bar/baz/baz.cr" exists (std, nested)
        basename = File.basename(relative_filename)
        yield "#{relative_filename}/#{basename}.cr"

        # If it's "foo/bar/baz", check if "foo/src/foo/bar/baz/baz.cr" exists (shard, non-namespaced, nested)
        yield "#{shard_src}/#{shard_path}/#{shard_path}.cr"

        # If it's "foo/bar/baz", check if "foo/src/foo/bar/baz/baz.cr" exists (shard, namespaced, nested)
        yield "#{shard_src}/#{shard_name}/#{shard_path}/#{shard_path}.cr"

        return nil
      end

      basename = File.basename(relative_filename)

      # If it's "foo", check if "foo/foo.cr" exists (for the std, nested)
      yield "#{relative_filename}/#{basename}.cr"

      unless filename_is_relative
        # If it's "foo", check if "foo/src/foo.cr" exists (for a shard)
        yield "#{relative_filename}/src/#{basename}.cr"
      end
    end

    private def gather_dir_files(dir, files_accumulator, recursive)
      files = [] of String
      dirs = [] of String

      Dir.each_child(dir) do |filename|
        full_name = "#{dir}/#{filename}"

        if File.directory?(full_name)
          if recursive
            dirs << filename
          end
        else
          if filename.ends_with?(".cr")
            files << full_name
          end
        end
      end

      files.sort!
      dirs.sort!

      files.each do |file|
        files_accumulator << File.expand_path(file)
      end

      dirs.each do |subdir|
        gather_dir_files("#{dir}/#{subdir}", files_accumulator, recursive)
      end
    end
  end

  class Bundler
    def initialize(@options : Options)
      @require_history = Set(String).new
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
        if absolute_paths = Path.find(path, file_name, @options.paths)
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
        Path.find(path, file_name, @options.paths) || Array(String).new
      end
    end
  end
end
