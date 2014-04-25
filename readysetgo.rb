require "pp"
require "json"
require "optparse"

def ready(name, &block)
  Ready.ready(name, &block)
end

module Ready
  ITERATIONS = 16

  def self.ready(name, &block)
    name = name.to_s
    configuration = Configuration.parse_options(ARGV)
    old_suite = Suite.load
    ready = Context.new(name, configuration, old_suite)
    ready.instance_eval(&block)
    ready.finish
  end

  class Configuration < Struct.new(:record, :compare)
    alias_method :record?, :record
    alias_method :compare?, :compare

    def self.parse_options(argv)
      record = false
      compare = false

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

        opts.on("--record", "Record the benchmark times") do
          record = true
        end

        opts.on("--compare", "Compare the benchmarks against the last saved run") do
          compare = true
        end
      end

      begin
        parser.parse(argv)
      rescue OptionParser::InvalidOption => e
        $stderr.puts e
        usage(parser)
      end

      usage(parser) unless record || compare

      new(record, compare)
    end

    def self.usage(parser)
      $stderr.puts parser
      exit 1
    end
  end

  class Context
    def initialize(name, configuration, old_suite)
      @name = name
      @set_block = lambda { }
      @after_block = lambda { }
      @configuration = configuration
      @old_suite = old_suite
      @suite = Suite.new
    end

    def set(&block)
      @set_block = block
    end

    def after(&block)
      @after_block = block
    end

    def go(name, &go_block)
      blocks = Blocks.new(@set_block, @after_block, go_block)
      full_name = @name + " " + name
      benchmark = Runner.new(full_name, blocks).run
      @suite = @suite.add(benchmark)
    end

    def finish
      @suite.save! if @configuration.record?
      show_comparison if @configuration.compare?
    end

    def show_comparison
      comparisons = Comparison.from_suites(@old_suite, @suite)
      comparisons.each do |comparison|
        puts comparison.name
        puts comparison.to_plot.map { |s| "  " + s }.join("\n")
      end
    end
  end

  class Blocks < Struct.new(:before, :after, :benchmark)
  end

  class Runner
    def initialize(name, blocks)
      @name = name
      @blocks = blocks
    end

    def run
      with_and_without_gc
    end

    def with_and_without_gc
      # Prime
      @blocks.before.call
      @blocks.benchmark.call

      STDERR.write @name + " "

      normal = record_run_times
      no_gc = disable_gc { record_run_times }

      STDERR.puts
      Benchmark.new(@name, normal, no_gc)
    end

    def disable_gc
      # Get as clean a GC state as we can before benchmarking
      GC.start

      GC.disable
      yield
    ensure
      GC.enable
      GC.start
    end

    def record_run_times
      (0...Ready::ITERATIONS).map do
        @blocks.before.call

        start = Time.now
        @blocks.benchmark.call
        end_time = Time.now
        time_in_ms = (end_time - start) * 1000

        @blocks.after.call

        STDERR.write "."
        STDERR.flush

        time_in_ms
      end
    end
  end

  class Suite
    attr_reader :runs

    def initialize(runs=[])
      @runs = runs
    end

    def self.load
      old_results = JSON.parse(File.read(".readygo"))
      runs = old_results.each_pair.map do |name, times|
        normal_times, no_gc_times = times
        Benchmark.new(name, normal_times, no_gc_times)
      end
      new(runs)
    end

    def add(run)
      Suite.new(@runs + [run])
    end

    def run_names
      @runs.map(&:name)
    end

    def run_named(name)
      run = @runs.find { |run| run.name == name }
      run or raise "Couldn't find run: #{name.inspect}"
    end

    def save!
      File.write(".readygo", JSON.dump(to_hash))
    end

    def to_hash
      Hash[runs.map do |run|
        [run.name, [run.normal.times, run.without_gc.times]]
      end]
    end
  end

  class Benchmark
    attr_reader :name, :normal, :without_gc

    def initialize(name, normal_times, no_gc_times)
      @name = name
      @normal = Series.new(normal_times)
      @without_gc = Series.new(no_gc_times)
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

  class PlotRenderer
    SCREEN_WIDTH = 80

    attr_reader :before, :after, :screen_width

    def initialize(before, after, screen_width=SCREEN_WIDTH)
      @before = before
      @after = after
      @screen_width = screen_width
    end

    def render
      titles.zip(bars).map { |title, bar| title + bar }
    end

    def titles
      [
        "Before (GC):    ",
        "Before (No GC): ",
        "After (GC):     ",
        "After (No GC):  ",
        "                ", # legend
      ]
    end

    def bars
      [
        BarRenderer.new(before.normal.stats, max_value, bar_length).render,
        BarRenderer.new(before.without_gc.stats, max_value, bar_length).render,
        BarRenderer.new(after.normal.stats, max_value, bar_length).render,
        BarRenderer.new(after.without_gc.stats, max_value, bar_length).render,
        legend,
      ]
    end

    def legend
      formatted_max = "%.3g" % max_value
      "0" + formatted_max.rjust(bar_length - 1)
    end

    def max_value
      [
        before.normal.max,
        before.without_gc.max,
        after.normal.max,
        after.without_gc.max
      ].max
    end

    def bar_length
      screen_width - titles.first.length
    end
  end

  class BarRenderer
    def initialize(series_statistics, max_value, bar_length)
      @statistics = series_statistics
      @max_value = max_value
      # Make room for pipes that we'll add to either side of the bar
      @bar_length = bar_length - 2
    end

    def render
      min = scale_value(@statistics.min)
      median = scale_value(@statistics.median)
      max = scale_value(@statistics.max)

      chars = (1..@bar_length).map do |i|
        case
        when i == median
          "*"
        when i >= min && i < median
          "-"
        when i <= max && i > median
          "-"
        else
          " "
        end
      end.join
      "|" + chars + "|"
    end

    def scale_value(value)
      (value.to_f / @max_value.to_f * @bar_length.to_f).round
    end
  end

  class Series
    attr_reader :times

    def initialize(times)
      @times = times
    end

    def median
      percentile(50)
    end

    def min
      times.min
    end

    def max
      times.max
    end

    def percentile(percentile)
      ratio = percentile * 0.01
      return times.min if percentile == 0
      return times.max if percentile == 100
      times_sorted = times.sort
      k = (ratio*(times_sorted.length-1)+1).floor - 1
      f = (ratio*(times_sorted.length-1)+1).modulo(1)

      return times_sorted[k] + (f * (times_sorted[k+1] - times_sorted[k]))
    end

    def stats
      SeriesStatistics.from_series(self)
    end

    def stat_string
      "range: %.3f - %.3f ms" % [min, max]
    end
  end

  class SeriesStatistics < Struct.new(:min,
                                      :percentile_25,
                                      :median,
                                      :percentile_75,
                                      :max)
    def self.from_series(series)
      new(series.min,
          series.percentile(25),
          series.median,
          series.percentile(75),
          series.max)
    end
  end
end
