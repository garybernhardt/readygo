module Ready
  class BenchmarkDefinition < Struct.new(:name,
                                         :procs,
                                         :enable_gc,
                                         :repetitions)

    extend Forwardable
    delegate :before_proc => :procs
    delegate :after_proc => :procs
    delegate :benchmark_proc => :procs
    delegate :nothing_proc => :procs

    alias_method :enable_gc?, :enable_gc

    def initialize(name, procs, enable_gc, repetitions=1)
      super(name, procs, enable_gc, repetitions)
    end

    def with_repetitions(repetitions)
      BenchmarkDefinition.new(name, procs, enable_gc, repetitions)
    end
  end

  # The `nothing` attribute exists to provide a way to measure baseline
  # performance to null out benchmarking overhead.
  class BenchmarkProcs < Struct.new(:before_proc,
                                    :after_proc,
                                    :benchmark_proc,
                                    :nothing_proc)
    def initialize(before_proc, after_proc, benchmark_proc)
      super(before_proc, after_proc, benchmark_proc, Proc.new { })
    end
  end

  class BenchmarkTime < Struct.new(:name, :time)
  end

  class Benchmark < Struct.new(:name, :times)
    def initialize(name, times)
      super(name, Series.new(times))
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
