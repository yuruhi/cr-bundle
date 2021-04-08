module CrBundle
  class Bundler
    def initialize(@source : String, @options : Options)
    end

    def bundle : String
      @source
    end
  end
end
