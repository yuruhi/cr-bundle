require "spec"
require "../src/cr-bundle"

def run_bundle(file)
  bundler = CrBundle::Bundler.new(CrBundle::Options.new)
  bundler.bundle(File.read(file), Path[file].expand)
end
