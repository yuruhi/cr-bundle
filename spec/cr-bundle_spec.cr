require "./spec_helper"
require "file_utils"

private def assert_finds(search, expected, rm_dir = nil, file = __FILE__, line = __LINE__)
  it "searchs #{search} and finds #{expected}", file, line do
    expected.each do |file|
      Dir.mkdir_p File.dirname(file)
      File.touch file
    end

    result = CrBundle::Path.find(search, Dir.current + "/a.cr", [Dir.current])
    result.should eq(expected.map { |file| File.expand_path file }), file: file, line: line

    expected.each { |file| File.delete file }
    FileUtils.rm_r rm_dir if rm_dir
  end
end

private def run_dependencies(file)
  CrBundle.dependencies(File.read(file), File.expand_path(file))
end

describe CrBundle::Path do
  assert_finds "foo.cr", ["foo.cr"]
  assert_finds "foo", ["foo.cr"]
  assert_finds "foo", ["foo/foo.cr"], "foo"
  assert_finds "foo", ["foo/src/foo.cr"], "foo/src"
  assert_finds "./foo.cr", ["foo.cr"]
  assert_finds "./foo", ["foo.cr"]
  assert_finds "./foo", ["foo/foo.cr"], "foo"
  assert_finds "../foo.cr", ["../foo.cr"]
  assert_finds "../foo", ["../foo.cr"]
  assert_finds "../foo", ["../foo/foo.cr"], "../foo"
  assert_finds "foo/bar.cr", ["foo/bar.cr"], "foo"
  assert_finds "foo/bar", ["foo/bar.cr"], "foo"
  assert_finds "foo/bar", ["foo/src/bar.cr"], "foo/src"
  assert_finds "foo/bar", ["foo/src/bar/bar.cr"], "foo/src/bar"
  assert_finds "./foo/bar.cr", ["foo/bar.cr"], "foo"
  assert_finds "./foo/bar", ["foo/bar.cr"], "foo"
  assert_finds "./foo/bar", ["foo/bar/bar.cr"], "foo/bar"
  assert_finds "../foo/bar.cr", ["../foo/bar.cr"], "../foo"
  assert_finds "../foo/bar", ["../foo/bar.cr"], "../foo"
  assert_finds "../foo/bar", ["../foo/bar/bar.cr"], "../foo/bar"
  assert_finds "foo/*", ["foo/1.cr", "foo/2.cr"], "foo"
  assert_finds "foo/**", ["foo/1.cr", "foo/2.cr", "foo/bar/1.cr"], "foo"
end

describe CrBundle do
  describe "bundle" do
    spec_absolute("./file.cr", "./file.cr")
    spec_absolute("./file", "./file.cr")
    spec_absolute("./file", "./file/file.cr", "file")
    spec_absolute("../file.cr", "../file.cr")
    spec_absolute("../file", "../file.cr")
    spec_absolute("../file", "../file/file.cr", "../file")
    spec_absolute("./foo/bar/baz", "./foo/bar/baz.cr", "foo")
    spec_absolute("./foo/bar/baz", "./foo/bar/baz/baz.cr", "foo")
    spec_absolute("../foo/bar/baz", "../foo/bar/baz.cr", "../foo")
    spec_absolute("../foo/bar/baz", "../foo/bar/baz/baz.cr", "../foo")

    it %[require "./dir/*"] do
      Dir.mkdir_p("dir/dir2")
      File.write("dir/1.cr", %["dir/1.cr"])
      File.write("dir/2.cr", %["dir/2.cr"])
      File.write("dir/dir2/3.cr", %["dir/dir2/3.cr"])
      File.write("a.cr", %[require "./dir/*"\n"a.cr"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./dir/*"
      "dir/1.cr"
      "dir/2.cr"
      "a.cr"
      RESULT
      FileUtils.rm_r("dir")
      FileUtils.rm("a.cr")
    end

    it %[require "./dir/**"] do
      Dir.mkdir_p("dir/dir2")
      File.write("dir/1.cr", %["dir/1.cr"])
      File.write("dir/2.cr", %["dir/2.cr"])
      File.write("dir/dir2/3.cr", %["dir/dir2/3.cr"])
      File.write("a.cr", %[require "./dir/**"\n"a.cr"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./dir/**"
      "dir/1.cr"
      "dir/2.cr"
      "dir/dir2/3.cr"
      "a.cr"
      RESULT
      FileUtils.rm_r("dir")
      FileUtils.rm("a.cr")
    end

    spec_relative("file.cr", "file.cr")
    spec_relative("file", "file.cr")
    spec_relative("file", "file/file.cr")
    spec_relative("file", "file/src/file.cr")
    spec_relative("foo/bar/baz.cr", "foo/bar/baz.cr")
    spec_relative("foo/bar/baz", "foo/bar/baz.cr")
    spec_relative("foo/bar/baz", "foo/bar/baz/baz.cr")
    spec_relative("foo/bar/baz", "foo/src/bar/baz.cr")
    spec_relative("/file.cr", "file.cr")
    spec_relative("/file", "file.cr")
    spec_relative("/file", "file/file.cr")

    it %[require "dir/*"] do
      Dir.mkdir_p("dir/dir2")
      File.write("dir/1.cr", %["dir/1.cr"])
      File.write("dir/2.cr", %["dir/2.cr"])
      File.write("dir/dir2/3.cr", %["dir/dir2/3.cr"])
      File.write("a.cr", %[require "dir/*"\n"a.cr"])
      run_bundle("a.cr", %w[.]).should eq <<-RESULT
      # require "dir/*"
      "dir/1.cr"
      "dir/2.cr"
      "a.cr"
      RESULT
      FileUtils.rm("a.cr")
      FileUtils.rm_r("dir")
    end

    it %[require "dir/**"] do
      Dir.mkdir_p("dir/dir2")
      File.write("dir/1.cr", %["dir/1.cr"])
      File.write("dir/2.cr", %["dir/2.cr"])
      File.write("dir/dir2/3.cr", %["dir/dir2/3.cr"])
      File.write("a.cr", %[require "dir/**"\n"a.cr"])
      run_bundle("a.cr", %w[.]).should eq <<-RESULT
      # require "dir/**"
      "dir/1.cr"
      "dir/2.cr"
      "dir/dir2/3.cr"
      "a.cr"
      RESULT
      FileUtils.rm_r("dir")
      FileUtils.rm("a.cr")
    end

    it "don't expand unknown files" do
      source = <<-SOURCE
      require "unknown_file"
      require "spec"
      require "bit_array"
      "a.cr"
      SOURCE
      File.write("a.cr", source)
      run_bundle("a.cr").should eq source
      File.delete("a.cr")
    end

    it "require same file" do
      File.write("a.cr", %["a.cr"])
      File.write("b1.cr", %[require "./a"\n"b1.cr"])
      File.write("b2.cr", %[require "./a"\n"b2.cr"])
      File.write("c.cr", %[require "./b1"\nrequire "./b2"\n"c.cr"])
      run_bundle("c.cr").should eq <<-RESULT
      # require "./b1"
      # require "./a"
      "a.cr"
      "b1.cr"
      # require "./b2"
      # require "./a"

      "b2.cr"
      "c.cr"
      RESULT
      FileUtils.rm(%w[a.cr b1.cr b2.cr c.cr])
    end

    it "require each other" do
      File.write("a.cr", %[require "./b"\n"a"])
      File.write("b.cr", %[require "./a"\n"b"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./b"
      # require "./a"

      "b"
      "a"
      RESULT
      FileUtils.rm(%w[a.cr b.cr])
    end

    it "require itself" do
      File.write("a.cr", %[require "./a"\n"a.cr"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./a"

      "a.cr"
      RESULT
      FileUtils.rm("a.cr")
    end

    it "require itself2" do
      Dir.mkdir("dir")
      File.write("dir/a.cr", %[require "./*"\n"a.cr"])
      run_bundle("dir/a.cr").should eq <<-RESULT
      # require "./*"

      "a.cr"
      RESULT
      FileUtils.rm_r("dir")
    end

    it "require itself3" do
      Dir.mkdir("dir")
      File.write("dir/a.cr", %[require "./**"\n"a.cr"])
      run_bundle("dir/a.cr").should eq <<-RESULT
      # require "./**"

      "a.cr"
      RESULT
      FileUtils.rm_r("dir")
    end

    it "require in the same line" do
      File.write("1.cr", %["1.cr"])
      File.write("2.cr", %["2.cr"])
      File.write("a.cr", %[require "./1"; require "./2"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./1"
      "1.cr"; # require "./2"
      "2.cr"
      RESULT
      FileUtils.rm(%w[a.cr 1.cr 2.cr])
    end

    it "don't expand require inside comments" do
      File.write("file.cr", %["file.cr"])
      File.write("a.cr", %[# require "./file"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./file"
      RESULT
      FileUtils.rm(%w[a.cr file.cr])
    end

    it "don't expand require inside strings" do
      File.write("file.cr", %["file.cr"])
      source = <<-'SOURCE'
      "requre \"./file\""
      %[require "./file"]
      %|require "./file"|
      %w[require "./file"]
      %w[require"./file"]
      <<-STRING
      require "./file"
      STRING
      "require \"./file\"
      require \"./file\"
      "
      SOURCE
      File.write("a.cr", source)
      run_bundle("a.cr").should eq source
      FileUtils.rm(%w[a.cr file.cr])
    end

    it "format" do
      File.write("a.cr", "p 1+1")
      options = CrBundle::Options.new
      options.format = true
      run_bundle("a.cr", options).should eq "p 1 + 1\n"
      FileUtils.rm("a.cr")
    end

    it "format after bundling" do
      File.write("file.cr", %[def a(b, c)\nb+c\nend])
      File.write("a.cr", %[require"./file.cr"\np a(1, 2)])
      options = CrBundle::Options.new
      options.format = true
      run_bundle("a.cr", options).should eq <<-RESULT
      # require "./file.cr"
      def a(b, c)
        b + c
      end

      p a(1, 2)

      RESULT
      FileUtils.rm(%w[file.cr a.cr])
    end
  end
  
  describe ".dependencies" do
    it "no dependencies" do
      File.write("a.cr", %["a.cr"])
      run_dependencies("a.cr").should eq [] of String      
      FileUtils.rm("a.cr")
    end

    it "one dependency" do
      File.write("file.cr", %["file.cr"])
      File.write("a.cr", %[require "./file.cr"])
      run_dependencies("a.cr").should eq [File.expand_path("file.cr")]
      FileUtils.rm(%w[file.cr a.cr])
    end

    it "two dependencies" do
      File.write("1.cr", %[1])
      File.write("2.cr", %[2])
      File.write("a.cr", %[require "./1.cr"\nrequire "./2.cr"])
      run_dependencies("a.cr").should eq %w[1.cr 2.cr].map { |s| File.expand_path(s) }
      FileUtils.rm(%w[1.cr 2.cr a.cr])
    end
  end
end
