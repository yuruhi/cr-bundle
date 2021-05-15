require "spec"
require "../src/cr-bundle"

def run_bundle(file, options = CrBundle::Options.new)
  bundler = CrBundle::Bundler.new(options)
  bundler.bundle(File.read(file), Path[file].expand)
end

def run_bundle(file, paths : Array(String))
  options = CrBundle::Options.new
  options.paths = paths.map { |s| Path[s] }
  run_bundle(file, options)
end

def run_dependencies(file)
  options = CrBundle::Options.new
  bundler = CrBundle::Bundler.new(options)
  bundler.dependencies(File.read(file), Path[file].expand)
end
