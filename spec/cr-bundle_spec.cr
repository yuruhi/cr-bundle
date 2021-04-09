require "./spec_helper"
require "file_utils"

describe CrBundle do
  describe "bundler" do
    it "standard" do
      File.write("a.cr", %[puts "a.cr"])
      File.write("b.cr", %[require "./a"\nputs "b.cr"])
      run_bundle("b.cr").should eq <<-RESULT
      # require "./a"
      puts "a.cr"
      puts "b.cr"
      RESULT
      FileUtils.rm(%w[a.cr b.cr])
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

      puts "b"
      puts "a"
      RESULT
      FileUtils.rm(%w[a.cr b.cr])
    end
  end
end
