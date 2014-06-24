module ReadyGo
  class Context
    attr_reader :suite, :definitions

    def initialize(name)
      @name = name
      @before_proc = lambda { }
      @after_proc = lambda { }
      @definitions = []
    end

    def before(&block)
      @before_proc = block
    end

    def after(&block)
      @after_proc = block
    end

    def go(name, options={}, &block)
      full_name = @name + " " + name
      procs = BenchmarkProcs.new(@before_proc, @after_proc, block)

      @definitions << BenchmarkDefinition.new(full_name, procs, :runtime)

      if options.fetch(:without_gc) { false }
        no_gc_name = full_name + " (GC Disabled)"
        @definitions << BenchmarkDefinition.new(no_gc_name, procs, :runtime_without_gc)
      end

      if options.fetch(:gc_time) { false }
        gc_time_name = full_name + " (GC Time)"
        @definitions << BenchmarkDefinition.new(gc_time_name, procs, :gc_time)
      end
    end
  end
end
