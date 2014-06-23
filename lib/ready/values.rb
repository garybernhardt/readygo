module Ready
  class BenchmarkDefinition < Struct.new(:name,
                                         :procs,
                                         :type,
                                         :repetitions)

    TYPES = [:runtime, :runtime_without_gc, :gc_time]

    extend Forwardable
    delegate :before_proc => :procs
    delegate :after_proc => :procs
    delegate :benchmark_proc => :procs
    delegate :nothing_proc => :procs

    def initialize(name, procs, type, repetitions=1)
      raise "BUG: unknown benchmark type #{type.inspect}" unless TYPES.include?(type)
      super(name, procs, type, repetitions)
    end

    def enable_gc?
      type != :runtime_without_gc
    end

    def record_runtime?
      [:runtime, :runtime_without_gc].include?(type)
    end

    def record_gc_time?
      type == :gc_time
    end

    def with_repetitions(repetitions)
      BenchmarkDefinition.new(name, procs, type, repetitions)
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
    def initialize(name, time)
      super
    end
  end

  class BenchmarkResult < Struct.new(:name, :times)
    def initialize(name, times)
      super(name, Series.new(times))
    end
  end

  class Comparison < Struct.new(:name, :before, :after)
    def to_plot(plot_width)
      PlotRenderer.new(self.before, self.after, plot_width).render
    end
  end

  class SeriesStatistics < Struct.new(:min, :percentile_80)
    def max_value
      [min, percentile_80].max
    end
  end
end
