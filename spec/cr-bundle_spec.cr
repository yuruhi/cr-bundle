require "./spec_helper"
require "file_utils"

describe CrBundle do
  describe "bundle" do
    spec_it("./file.cr", "./file.cr")
    spec_it("./file", "./file.cr")
    spec_it("./file", "./file/file.cr", "file")
    spec_it("../file.cr", "../file.cr")
    spec_it("../file", "../file.cr")
    spec_it("../file", "../file/file.cr", "../file")
    spec_it("./foo/bar/baz", "./foo/bar/baz.cr", "foo")
    spec_it("./foo/bar/baz", "./foo/bar/baz/baz.cr", "foo")
    spec_it("../foo/bar/baz", "../foo/bar/baz.cr", "../foo")
    spec_it("../foo/bar/baz", "../foo/bar/baz/baz.cr", "../foo")

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

    spec_with_path("file.cr", "file.cr")
    spec_with_path("file", "file.cr")
    spec_with_path("file", "file/file.cr")
    spec_with_path("file", "file/src/file.cr")
    spec_with_path("file", "file/src/file/file.cr")
    spec_with_path("foo/bar/baz.cr", "foo/bar/baz.cr")
    spec_with_path("foo/bar/baz", "foo/bar/baz.cr")
    spec_with_path("foo/bar/baz", "foo/bar/baz/baz.cr")
    spec_with_path("foo/bar/baz", "foo/src/bar/baz.cr")
    spec_with_path("foo/bar/baz", "foo/src/bar/baz/baz.cr")
    spec_with_path("/file.cr", "file.cr")
    spec_with_path("/file", "file.cr")
    spec_with_path("/file", "file/file.cr")

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

  describe "dependencies" do
    it "no dependencies" do
      File.write("a.cr", %["a.cr"])
      run_dependencies("a.cr").should eq [] of Path
      FileUtils.rm("a.cr")
    end
    it "one dependency" do
      File.write("file.cr", %["file.cr"])
      File.write("a.cr", %[require "./file.cr"])
      run_dependencies("a.cr").should eq [Path["file.cr"].expand]
      FileUtils.rm(%w[file.cr a.cr])
    end
    it "two dependencies" do
      File.write("1.cr", %[1])
      File.write("2.cr", %[2])
      File.write("a.cr", %[require "./1.cr"\nrequire "./2.cr"])
      run_dependencies("a.cr").should eq %w[1.cr 2.cr].map { |s| Path[s].expand }
      FileUtils.rm(%w[1.cr 2.cr a.cr])
    end
  end
end
