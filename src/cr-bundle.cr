require "option_parser"
require "colorize"
require "./bundler"

module CrBundle
  VERSION = "0.1.0"
  BANNER  = <<-HELP_MESSAGE
      cr-bundle is a crystal language's bundler.

      usage: cr-bundle [programfile]

      HELP_MESSAGE

  class Options
    property inplace : Bool = false
    property paths : Array(Path) = [] of Path
    property format : Bool = false
  end

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
      options = Options.new
      source = nil
      file_name = nil
      dependencies = false
      if paths = ENV["CR_BUNDLE_PATH"]?
        options.paths = paths.split(':').map { |s| Path[s] }
      end

      parser = OptionParser.new
      parser.banner = BANNER

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
        file_name = Path[Dir.current]
      end
      parser.on("-i", "--inplace", "inplace edit") do
        options.inplace = true
      end
      parser.on("-f", "--format", "run format after bundling") do
        options.format = true
      end
      parser.on("-p PATH", "--path PATH", "indicate require path\n(you can be specified with the environment `CR_BUNDLE_PATH`)") do |path|
        if options.paths.empty?
          options.paths = path.split(':').map { |s| Path[s] }
        else
          info("Ignored -p option since set environment CR_BUNDLE_PATH.")
        end
      end

      parser.on("-d", "--dependencies", "output dependencies") do
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
            error("Cannot use -i when reading from stdin.") if options.inplace
            source = STDIN.gets_to_end
          else
            file = unknown_args[0]
            if !File.exists?(file)
              error("No such file or directory: `#{unknown_args[0]}`")
            elsif File.directory?(file)
              error("Is a directory: `#{file}`")
            end
            source = File.read(unknown_args[0])
            file_name = Path[file].expand
            unknown_args[1..].each { |file|
              info("File #{file} is ignored.")
            }
          end
        else
          error("Cannot use -i when using -e") if options.inplace
          unknown_args.each { |file|
            info("File #{file} is ignored.")
          }
        end
      end

      parser.parse(args)

      if dependencies
        puts Bundler.new(options).dependencies(source.not_nil!, file_name.not_nil!).join('\n')
      else
        bundled = Bundler.new(options).bundle(source.not_nil!, file_name.not_nil!)
        if options.inplace
          File.write(file_name.not_nil!, bundled.to_slice)
        else
          puts bundled
        end
      end
    end
  end
end
