require "./spec_helper"
require "file_utils"

describe CrBundle do
  describe "bundle" do
    it %[require "./file" and expand "./file.cr"] do
      File.write("file.cr", %[puts "file.cr"])
      File.write("a.cr", %[require "./file"\nputs "a.cr"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./file"
      puts "file.cr"
      puts "a.cr"
      RESULT
      FileUtils.rm(%w[a.cr file.cr])
    end
    it %[require "./file.cr" and expand "./file.cr"] do
      File.write("file.cr", %[puts "file.cr"])
      File.write("a.cr", %[require "./file.cr"\nputs "a.cr"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./file.cr"
      puts "file.cr"
      puts "a.cr"
      RESULT
      FileUtils.rm(%w[a.cr file.cr])
    end
    it %[require "./file" and expand "./file/file.cr"] do
      Dir.mkdir("file")
      File.write("file/file.cr", %[puts "file/file.cr"])
      File.write("a.cr", %[require "./file"\nputs "a.cr"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./file"
      puts "file/file.cr"
      puts "a.cr"
      RESULT
      FileUtils.rm_r("file")
      FileUtils.rm("a.cr")
    end
    it %[require "../file" and expand "../file.cr"] do
      Dir.mkdir("dir")
      File.write("file.cr", %[puts "file.cr"])
      File.write("dir/a.cr", %[require "../file"\nputs "dir/a.cr"])
      run_bundle("dir/a.cr").should eq <<-RESULT
      # require "../file"
      puts "file.cr"
      puts "dir/a.cr"
      RESULT
      FileUtils.rm_r("dir")
      FileUtils.rm("file.cr")
    end
    it %[require "../file.cr" and expand "../file.cr"] do
      Dir.mkdir("dir")
      File.write("file.cr", %[puts "file.cr"])
      File.write("dir/a.cr", %[require "../file.cr"\nputs "dir/a.cr"])
      run_bundle("dir/a.cr").should eq <<-RESULT
      # require "../file.cr"
      puts "file.cr"
      puts "dir/a.cr"
      RESULT
      FileUtils.rm_r("dir")
      FileUtils.rm("file.cr")
    end
    it %[require "../file" and expand "../file/file.cr"] do
      Dir.mkdir("file")
      File.write("file/file.cr", %[puts "file/file.cr"])
      Dir.mkdir("dir")
      File.write("dir/a.cr", %[require "../file"\nputs "dir/a.cr"])
      run_bundle("dir/a.cr").should eq <<-RESULT
      # require "../file"
      puts "file/file.cr"
      puts "dir/a.cr"
      RESULT
      FileUtils.rm_r(%w[file dir])
    end

    it %[require "./dir/*"] do
      Dir.mkdir_p("dir/dir2")
      File.write("dir/1.cr", %[puts "dir/1.cr"])
      File.write("dir/2.cr", %[puts "dir/2.cr"])
      File.write("dir/dir2/3.cr", %[puts "dir/dir2/3.cr"])
      File.write("a.cr", %[require "./dir/*"\nputs "a.cr"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./dir/*"
      puts "dir/1.cr"
      puts "dir/2.cr"
      puts "a.cr"
      RESULT
      FileUtils.rm_r("dir")
      FileUtils.rm("a.cr")
    end
    it %[require "./dir/**"] do
      Dir.mkdir_p("dir/dir2")
      File.write("dir/1.cr", %[puts "dir/1.cr"])
      File.write("dir/2.cr", %[puts "dir/2.cr"])
      File.write("dir/dir2/3.cr", %[puts "dir/dir2/3.cr"])
      File.write("a.cr", %[require "./dir/**"\nputs "a.cr"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./dir/**"
      puts "dir/1.cr"
      puts "dir/2.cr"
      puts "dir/dir2/3.cr"
      puts "a.cr"
      RESULT
      FileUtils.rm_r("dir")
      FileUtils.rm("a.cr")
    end

    it %[require "file.cr" and expand "file.cr"] do
      Dir.mkdir("dir")
      File.write("dir/file.cr", %[puts "file.cr"])
      File.write("a.cr", %[require "file.cr"\nputs "a.cr"])
      run_bundle("a.cr", %w[dir]).should eq <<-RESULT
      # require "file.cr"
      puts "file.cr"
      puts "a.cr"
      RESULT
      FileUtils.rm("a.cr")
      FileUtils.rm_r("dir")
    end
    it %[require "file" and expand "file.cr"] do
      Dir.mkdir("dir") unless Dir.exists?("dir")
      File.write("dir/file.cr", %[puts "file.cr"])
      File.write("a.cr", %[require "file"\nputs "a.cr"])
      run_bundle("a.cr", %w[dir]).should eq <<-RESULT
      # require "file"
      puts "file.cr"
      puts "a.cr"
      RESULT
      FileUtils.rm("a.cr")
      FileUtils.rm_r("dir")
    end
    it %[require "file" and expand "file/file.cr"] do
      Dir.mkdir_p("dir/file")
      File.write("dir/file/file.cr", %[puts "file.cr"])
      File.write("a.cr", %[require "file"\nputs "a.cr"])
      run_bundle("a.cr", %w[dir]).should eq <<-RESULT
      # require "file"
      puts "file.cr"
      puts "a.cr"
      RESULT
      FileUtils.rm("a.cr")
      FileUtils.rm_r("dir")
    end
    it %[require "file" and expand "file/src/file.cr"] do
      Dir.mkdir_p("dir/file/src")
      File.write("dir/file/src/file.cr", %[puts "file.cr"])
      File.write("a.cr", %[require "file"\nputs "a.cr"])
      run_bundle("a.cr", %w[dir]).should eq <<-RESULT
      # require "file"
      puts "file.cr"
      puts "a.cr"
      RESULT
      FileUtils.rm("a.cr")
      FileUtils.rm_r("dir")
    end
    it %[require "file" and expand "file/src/file/file.cr"] do
      Dir.mkdir_p("dir/file/src/file")
      File.write("dir/file/src/file/file.cr", %[puts "file.cr"])
      File.write("a.cr", %[require "file"\nputs "a.cr"])
      run_bundle("a.cr", %w[dir]).should eq <<-RESULT
      # require "file"
      puts "file.cr"
      puts "a.cr"
      RESULT
      FileUtils.rm("a.cr")
      FileUtils.rm_r("dir")
    end
    it %[require "dir/*"] do
      Dir.mkdir_p("dir/dir2")
      File.write("dir/1.cr", %[puts "dir/1.cr"])
      File.write("dir/2.cr", %[puts "dir/2.cr"])
      File.write("dir/dir2/3.cr", %[puts "dir/dir2/3.cr"])
      File.write("a.cr", %[require "dir/*"\nputs "a.cr"])
      run_bundle("a.cr", %w[.]).should eq <<-RESULT
      # require "dir/*"
      puts "dir/1.cr"
      puts "dir/2.cr"
      puts "a.cr"
      RESULT
      FileUtils.rm("a.cr")
      FileUtils.rm_r("dir")
    end
    it %[require "dir/**"] do
      Dir.mkdir_p("dir/dir2")
      File.write("dir/1.cr", %[puts "dir/1.cr"])
      File.write("dir/2.cr", %[puts "dir/2.cr"])
      File.write("dir/dir2/3.cr", %[puts "dir/dir2/3.cr"])
      File.write("a.cr", %[require "dir/**"\nputs "a.cr"])
      run_bundle("a.cr", %w[.]).should eq <<-RESULT
      # require "dir/**"
      puts "dir/1.cr"
      puts "dir/2.cr"
      puts "dir/dir2/3.cr"
      puts "a.cr"
      RESULT
      FileUtils.rm_r("dir")
      FileUtils.rm("a.cr")
    end

    it "require same file" do
      File.write("a.cr", %[puts "a.cr"])
      File.write("b1.cr", %[require "./a"\nputs "b1.cr"])
      File.write("b2.cr", %[require "./a"\nputs "b2.cr"])
      File.write("c.cr", %[require "./b1"\nrequire "./b2"\nputs "c.cr"])
      run_bundle("c.cr").should eq <<-RESULT
      # require "./b1"
      # require "./a"
      puts "a.cr"
      puts "b1.cr"
      # require "./b2"
      # require "./a"
      
      puts "b2.cr"
      puts "c.cr"
      RESULT
      FileUtils.rm(%w[a.cr b1.cr b2.cr c.cr])
    end
    it "require each other" do
      File.write("a.cr", %[require "./b"\nputs "a"])
      File.write("b.cr", %[require "./a"\nputs "b"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./b"
      # require "./a"

      puts "b"
      puts "a"
      RESULT
      FileUtils.rm(%w[a.cr b.cr])
    end
    it "require in the same line" do
      File.write("1.cr", %[puts "1.cr"])
      File.write("2.cr", %[puts "2.cr"])
      File.write("a.cr", %[require "./1"; require "./2"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./1"
      puts "1.cr"; # require "./2"
      puts "2.cr"
      RESULT
      FileUtils.rm(%w[a.cr 1.cr 2.cr])
    end

    it "don't expand require inside comments" do
      File.write("file.cr", %[puts "file.cr"])
      File.write("a.cr", %[# require "./file"])
      run_bundle("a.cr").should eq <<-RESULT
      # require "./file"
      RESULT
      FileUtils.rm(%w[a.cr file.cr])
    end
    it "don't expand require inside strings" do
      File.write("file.cr", %[puts "file.cr"])
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
      File.write("a.cr", %[puts "a.cr"])
      run_dependencies("a.cr").should eq [] of Path
      FileUtils.rm("a.cr")
    end
    it "one dependency" do
      File.write("file.cr", %[puts "file.cr"])
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
