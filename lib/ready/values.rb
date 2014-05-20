module Ready
  # A benchmark specification, mostly composed of the relevant blocks. The
  # `nothing` attribute exists to provide a way to measure baseline
  # performance to null out benchmarking overhead.
  class BenchmarkDefinition < Struct.new(:name,
                                         :before_proc,
                                         :after_proc,
                                         :benchmark_proc,
                                         :enable_gc,
                                         :repetitions,
                                         :nothing_proc)

    alias_method :enable_gc?, :enable_gc

    def initialize(name, before_proc, after_proc, benchmark_proc, enable_gc, repetitions=1)
      super(name, before_proc, after_proc, benchmark_proc, enable_gc, repetitions, lambda { })
    end

    def with_repetitions(repetitions)
      BenchmarkDefinition.new(name, before_proc, after_proc, benchmark_proc, enable_gc, repetitions)
    end
  end

  class BenchmarkTime < Struct.new(:name, :time)
  end

  class Benchmark
    attr_reader :name, :times

    def initialize(name, times)
      @name = name
      @times = Series.new(times)
    end
  end

  class Comparison < Struct.new(:name, :before, :after)
    def self.from_suites(old_suite, new_suite)
      names = new_suite.run_names
      names.map do |name|
        Comparison.new(name,
                       old_suite.run_named(name),
                       new_suite.run_named(name))
      end
    end

    def to_plot
      PlotRenderer.new(self.before, self.after).render
    end
  end

  class SeriesStatistics < Struct.new(:min,
                                      :median,
                                      :max)
  end
end
