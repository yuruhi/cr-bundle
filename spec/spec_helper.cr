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

macro spec_absolute(require_file, actual_file, rm_dir = "")
  it %[require {{require_file}} and expand {{actual_file}}] do
    require_file = Path[{{require_file}}]
    actual_file = Path[{{actual_file}}]
    Dir.mkdir_p(actual_file.dirname)
    File.write(actual_file, %["#{actual_file}"])
    File.write("a.cr", %[require "#{require_file}"\n"a.cr"])

    run_bundle("a.cr").should eq <<-RESULT
    # require "#{require_file}"
    "#{actual_file}"
    "a.cr"
    RESULT

    File.delete(actual_file)
    File.delete("a.cr")
    FileUtils.rm_r({{rm_dir}}) unless {{rm_dir}}.empty?
  end
end

macro spec_relative(require_file, actual_file)
  it %[require {{require_file}} and expand {{actual_file}}] do
    require_file = Path[{{require_file}}]
    actual_file = Path["dir"] / Path[{{actual_file}}]
    Dir.mkdir_p(actual_file.dirname)
    File.write(actual_file, %["#{actual_file}"])
    File.write("a.cr", %[require "#{require_file}"\n"a.cr"])

    run_bundle("a.cr", ["dir"]).should eq <<-RESULT
    # require "#{require_file}"
    "#{actual_file}"
    "a.cr"
    RESULT

    File.delete(actual_file)
    File.delete("a.cr")
    FileUtils.rm_r("dir")
  end
end
