require "option_parser"
require "colorize"
require "./bundler"

module CrBundle
  VERSION = "0.1.0"
  BANNER  = <<-HELP_MESSAGE
      cr-bundle is a crystal language's bundler.

      usage: jigsaw [programfile]

      HELP_MESSAGE

  class Options
    property inplace : Bool = false
    property args : Array(String) = [] of String
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

      parser = OptionParser.new
      parser.banner = BANNER

      parser.on("-v", "--version", "show the cppminify version number") do
        puts "cppminify #{VERSION}"
        exit
      end
      parser.on("-h", "--help", "show this help message and exit") do
        puts parser
        exit
      end

      parser.on("-e SOURCE", "--eval SOURCE", "eval code from args") do |eval_source|
        source = eval_source
      end
      parser.on("-i", "--inplace", "inplace edit") do
        options.inplace = true
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
            file_name = file
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

      bundled = Bundler.new(source.not_nil!, options).bundle
      if options.inplace
        File.write(file_name.not_nil!, bundled.to_slice)
      else
        puts bundled
      end
    end
  end
end
