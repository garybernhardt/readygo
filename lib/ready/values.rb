module Ready
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

  class BenchmarkResult < Struct.new(:name, :times, :stats)
    def initialize(name, times)
      super(name, times, SeriesStatistics.from_times(times))
    end
  end

  class Comparison < Struct.new(:name, :before, :after)
    def to_plot(plot_width)
      PlotRenderer.new(self.before, self.after, plot_width).render
    end
  end

  class SeriesStatistics < Struct.new(:min, :percentile_80)
    def self.from_times(times)
      new(times.min, Statistics.percentile(times, 80))
    end
  end
end
