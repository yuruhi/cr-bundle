require "option_parser"
require "colorize"
require "./bundler"

module CrBundle
  VERSION = "0.3.2"

  class CLI
    def error(message)
      STDERR.puts "[#{"ERROR".colorize(:red)}] #{message}"
      exit(1)
    end

    def error_usage(message, parser)
      STDERR.puts "[#{"ERROR".colorize(:red)}] #{message}"
      STDERR.puts parser
      exit(1)
    end

    def info(message)
      STDERR.puts "[#{"INFO".colorize(:blue)}] #{message}"
    end

    def run(args = ARGV)
      source, filename = nil, nil
      dependencies, inplace, format = false, false, false
      paths = ENV["CR_BUNDLE_PATH"]?.try(&.split(':')) || [] of String

      OptionParser.parse(args) do |parser|
        parser.banner = <<-HELP_MESSAGE
        cr-bundle is a crystal language's bundler.

        usage: cr-bundle [programfile]

        HELP_MESSAGE

        parser.on("-v", "--version", "show the cr-bundle version number") do
          puts "cr-bundle #{VERSION}"
          exit
        end
        parser.on("-h", "--help", "show this help message") do
          puts parser
          exit
        end

        parser.on("-e SOURCE", "--eval SOURCE", "eval code from args") do |eval_source|
          source = eval_source
        end
        parser.on("-i", "--inplace", "inplace edit") do
          inplace = true
        end
        parser.on("-f", "--format", "run format after bundling") do
          format = true
        end
        parser.on("-p PATH", "--path PATH", "indicate require path\n(you can be specified with the environment `CR_BUNDLE_PATH`)") do |path|
          if paths.nil? || paths.try &.empty?
            paths = path.split(':')
          else
            info("Ignored -p option since set environment CR_BUNDLE_PATH.")
          end
        end

        parser.on("-d", "--dependencies", "output dependencies") do
          info("Ignored -i option.") if inplace
          info("Ignored -f option.") if format
          dependencies = true
        end

        parser.missing_option do |option|
          puts option
          error("Missing option: #{option}")
        end

        parser.invalid_option do |flag|
          error_usage("Invalid option: #{flag}", parser)
        end

        parser.unknown_args do |unknown_args|
          if source.nil?
            if unknown_args.size == 0
              error("Cannot use -i when reading from stdin.") if inplace
              source = STDIN.gets_to_end
            else
              file = unknown_args[0]
              if !File.exists?(file)
                error("No such file or directory: `#{unknown_args[0]}`")
              elsif File.directory?(file)
                error("Is a directory: `#{file}`")
              end
              source = File.read(unknown_args[0])
              filename = File.expand_path(file)
              unknown_args[1..].each do |file|
                info("File #{file} is ignored.")
              end
            end
          else
            error("Cannot use -i when using -e") if inplace
            unknown_args.each do |file|
              info("File #{file} is ignored.")
            end
          end
        end
      end

      raise "Bug" if source.nil?
      filename = "#{Dir.current}/_.cr" if filename.nil?

      if dependencies
        puts CrBundle.dependencies(source.not_nil!, filename.not_nil!, paths).join('\n')
      else
        bundled = CrBundle.bundle(source.not_nil!, filename.not_nil!, paths, format)
        if inplace
          File.write(filename.not_nil!, bundled.to_slice)
        else
          puts bundled
        end
      end
    end
  end
end
