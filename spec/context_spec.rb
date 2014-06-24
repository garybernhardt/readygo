require "spec_helper"

module ReadyGo
  describe Context do
    it "creates benchmark definitions" do
      context = Context.new("a context")
      context.go("a benchmark") { "a benchmark block" }
      context.definitions.count.should == 1
      definition = context.definitions.first
      definition.name.should == "a context a benchmark"
      definition.type.should == :runtime
    end

    it "creates benchmark definitions without GC when asked" do
      context = Context.new("a context")
      context.go("a benchmark", :without_gc => true) { "a benchmark block" }
      context.definitions.count.should == 2
      definition = context.definitions[1]
      definition.name.should == "a context a benchmark (GC Disabled)"
      definition.type.should == :runtime_without_gc
    end

    it "creates benchmark definitions for GC time when asked" do
      context = Context.new("a context")
      context.go("a benchmark", :gc_time => true) { "a benchmark block" }
      context.definitions.count.should == 2
      definition = context.definitions[1]
      definition.name.should == "a context a benchmark (GC Time)"
      definition.type.should == :gc_time
    end
  end
end
