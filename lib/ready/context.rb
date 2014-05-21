module Ready
  class Context
    def initialize(name, configuration, old_suite)
      @name = name
      @before_proc = lambda { }
      @after_proc = lambda { }
      @definitions = []
      @configuration = configuration
      @old_suite = old_suite
      @suite = Suite.new
    end

    def self.all
      @all ||= []
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

    def finish
      BenchmarkCollection.new(@definitions).run.each do |benchmark_result|
        @suite = @suite.add(benchmark_result)
      end

      Serializer.save!(@suite) if @configuration.record?
      show_comparison if @configuration.compare?
    end

    def show_comparison
      comparisons = @old_suite.compare(@suite)
      comparisons.each do |comparison|
        puts
        puts comparison.name
        puts comparison.to_plot.map { |s| "  " + s }.join("\n")
      end
    end
  end
end
