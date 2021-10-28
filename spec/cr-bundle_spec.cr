require "spec"
require "file_utils"
require "../src/bundler"

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

private def assert_bundles(source, filename, expected, *, paths = [] of String, format = false, file = __FILE__, line = __LINE__)
  bundled = CrBundle.bundle(source, File.expand_path(filename), paths, format)
  bundled.should eq(expected), file: file, line: line
end

private def assert_bundles(filename, expected, *, paths = [] of String, format = false, file = __FILE__, line = __LINE__)
  bundled = CrBundle.bundle(File.read(filename), File.expand_path(filename), paths, format)
  bundled.should eq(expected), file: file, line: line
end

private def run_dependencies(file)
  CrBundle.dependencies(File.read(file), File.expand_path(file))
end

private def run_bundle(file, *, format : Bool = false)
  CrBundle.bundle(File.read(file), File.expand_path(file), [] of String, format)
end

private def run_bundle(file, paths : Array(String))
  CrBundle.bundle(File.read(file), File.expand_path(file), paths, false)
end

describe CrBundle::Path do
  assert_finds "foo.cr", ["foo.cr"]
  assert_finds "foo", ["foo.cr"]
  assert_finds "foo", ["foo/foo.cr"], "foo"
  assert_finds "foo", ["foo/src/foo.cr"], "foo/src"
  assert_finds "/foo.cr", ["foo.cr"]
  assert_finds "/foo", ["foo.cr"]
  assert_finds "/foo", ["foo/foo.cr"], "foo"
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
  describe ".bundle" do
    it %[require "./file"] do
      File.write("file.cr", %["file.cr"])
      assert_bundles(<<-SOURCE, "a.cr", <<-EXPECTED)
      require "./file"
      "a.cr"
      SOURCE
      # require "./file"
      "file.cr"
      "a.cr"
      EXPECTED
    end

    it %[require "./dir/*"] do
      Dir.mkdir_p("dir/dir2")
      File.write("dir/1.cr", %["dir/1.cr"])
      File.write("dir/2.cr", %["dir/2.cr"])
      File.write("dir/dir2/3.cr", %["dir/dir2/3.cr"])

      assert_bundles(<<-SOURCE, "a.cr", <<-EXPECTED)
      require "./dir/*"
      "a.cr"
      SOURCE
      # require "./dir/*"
      "dir/1.cr"
      "dir/2.cr"
      "a.cr"
      EXPECTED

      FileUtils.rm_r("dir")
    end

    it %[require "./dir/**"] do
      Dir.mkdir_p("dir/dir2")
      File.write("dir/1.cr", %["dir/1.cr"])
      File.write("dir/2.cr", %["dir/2.cr"])
      File.write("dir/dir2/3.cr", %["dir/dir2/3.cr"])

      assert_bundles(<<-SOURCE, "a.cr", <<-EXPECTED)
      require "./dir/**"
      "a.cr"
      SOURCE
      # require "./dir/**"
      "dir/1.cr"
      "dir/2.cr"
      "dir/dir2/3.cr"
      "a.cr"
      EXPECTED

      FileUtils.rm_r("dir")
    end

    it %[require "file"] do
      File.write("file.cr", %["file.cr"])
      assert_bundles(<<-SOURCE, "a.cr", <<-EXPECTED, paths: %w[.])
      require "file"
      "a.cr"
      SOURCE
      # require "file"
      "file.cr"
      "a.cr"
      EXPECTED
    end

    it %[require "dir/*"] do
      Dir.mkdir_p("dir/dir2")
      File.write("dir/1.cr", %["dir/1.cr"])
      File.write("dir/2.cr", %["dir/2.cr"])
      File.write("dir/dir2/3.cr", %["dir/dir2/3.cr"])

      assert_bundles(<<-SOURCE, "a.cr", <<-EXPECTED, paths: %w[.])
      require "dir/*"
      "a.cr"
      SOURCE
      # require "dir/*"
      "dir/1.cr"
      "dir/2.cr"
      "a.cr"
      EXPECTED

      FileUtils.rm_r("dir")
    end

    it %[require "dir/**"] do
      Dir.mkdir_p("dir/dir2")
      File.write("dir/1.cr", %["dir/1.cr"])
      File.write("dir/2.cr", %["dir/2.cr"])
      File.write("dir/dir2/3.cr", %["dir/dir2/3.cr"])

      assert_bundles(<<-SOURCE, "a.cr", <<-EXPECTED, paths: %w[.])
      require "dir/**"
      "a.cr"
      SOURCE
      # require "dir/**"
      "dir/1.cr"
      "dir/2.cr"
      "dir/dir2/3.cr"
      "a.cr"
      EXPECTED

      FileUtils.rm_r("dir")
    end

    it "don't expand unknown files" do
      source = <<-SOURCE
      require "unknown_file"
      require "spec"
      require "bit_array"
      "a.cr"
      SOURCE

      assert_bundles(source, "a.cr", source)
    end

    it "require same file" do
      File.write("a.cr", %["a.cr"])
      File.write("b1.cr", %[require "./a"\n"b1.cr"])
      File.write("b2.cr", %[require "./a"\n"b2.cr"])

      assert_bundles(<<-SOURCE, "c.cr", <<-EXPECTED)
      require "./b1"
      require "./b2"
      "c.cr"
      SOURCE
      # require "./b1"
      # require "./a"
      "a.cr"
      "b1.cr"
      # require "./b2"
      # require "./a"

      "b2.cr"
      "c.cr"
      EXPECTED

      FileUtils.rm(%w[a.cr b1.cr b2.cr])
    end

    it "require each other" do
      File.write("a.cr", %[require "./b"\n"a"])
      File.write("b.cr", %[require "./a"\n"b"])
      assert_bundles("a.cr", <<-EXPECTED)
      # require "./b"
      # require "./a"

      "b"
      "a"
      EXPECTED
      FileUtils.rm(%w[a.cr b.cr])
    end

    it "require itself" do
      File.write("a.cr", %[require "./a"\n"a.cr"])
      assert_bundles("a.cr", <<-EXPECTED)
      # require "./a"

      "a.cr"
      EXPECTED
      File.delete("a.cr")
    end

    it "require itself2" do
      Dir.mkdir("dir")
      File.write("dir/a.cr", %[require "./*"\n"a.cr"])
      assert_bundles("dir/a.cr", <<-EXPECTED)
      # require "./*"

      "a.cr"
      EXPECTED
      FileUtils.rm_r("dir")
    end

    it "require itself3" do
      Dir.mkdir("dir")
      File.write("dir/a.cr", %[require "./**"\n"a.cr"])
      assert_bundles("dir/a.cr", <<-EXPECTED)
      # require "./**"

      "a.cr"
      EXPECTED
      FileUtils.rm_r("dir")
    end

    it "require in the same line" do
      File.write("1.cr", %["1.cr"])
      File.write("2.cr", %["2.cr"])
      assert_bundles(<<-SOURCE, "a.cr", <<-EXPECTED)
      require "./1"; require "./2"
      "a.cr"
      SOURCE
      # require "./1"
      "1.cr"; # require "./2"
      "2.cr"
      "a.cr"
      EXPECTED
      FileUtils.rm(%w[1.cr 2.cr])
    end

    it "don't expand require inside comments" do
      File.write("file.cr", %["file.cr"])
      assert_bundles(<<-SOURCE, "a.cr", <<-EXPECTED)
      # require "./file"
      SOURCE
      # require "./file"
      EXPECTED
      FileUtils.rm(%w[file.cr])
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
      assert_bundles(source, "a.cr", source)
      FileUtils.rm("file.cr")
    end

    it "format" do
      assert_bundles("p 1+1", "a.cr", "p 1 + 1\n", format: true)
    end

    it "format after bundling" do
      File.write("file.cr", %[def a(b, c)\nb+c\nend])
      assert_bundles(<<-SOURCE, "a.cr", <<-EXPECTED, format: true)
      require"./file"
      p a(1, 2)
      SOURCE
      # require "./file"
      def a(b, c)
        b + c
      end
      
      p a(1, 2)

      EXPECTED
      FileUtils.rm("file.cr")
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
