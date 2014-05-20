require "pp"
require "json"
require "optparse"

def ready(name, &block)
  Ready.ready(name, &block)
end

module Ready
  ITERATIONS = 16
  MINIMUM_MS = 1

  def self.main
    load_files(configuration.files)
    Context.all.each { |context| context.finish }
  end

  def self.ready(name, &block)
    name = name.to_s
    load_files(configuration.files)
    old_suite = Suite.load
    context = Context.new(name, configuration, old_suite)
    context.instance_eval(&block)
    Context.all << context
  end

  def self.configuration
    @configuration ||= Configuration.parse_options(ARGV)
  end

  def self.load_files(files)
    $LOAD_PATH.unshift "."
    files.each { |file| require file }
  end

  class Configuration < Struct.new(:record, :compare, :files)
    alias_method :record?, :record
    alias_method :compare?, :compare

    def self.parse_options(argv)
      argv = argv.dup

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
        parser.parse!(argv)
      rescue OptionParser::InvalidOption => e
        $stderr.puts e
        usage(parser)
      end

      usage(parser) unless record || compare

      files = argv
      new(record, compare, files)
    end

    def self.usage(parser)
      $stderr.puts parser
      exit 1
    end
  end

  class Context
    def initialize(name, configuration, old_suite)
      @name = name
      @set_proc = lambda { }
      @after_proc = lambda { }
      @all_definitions = []
      @configuration = configuration
      @old_suite = old_suite
      @suite = Suite.new
    end

    def self.all
      @all ||= []
    end

    def set(&block)
      @set_proc = block
    end

    def after(&block)
      @after_proc = block
    end

    def go(name, options={}, &block)
      full_name = @name + " " + name
      @all_definitions += [
        BenchmarkDefinition.new(full_name + " (GC)",
                                @set_proc, @after_proc, block, true),
        BenchmarkDefinition.new(full_name + " (No GC)",
                                @set_proc, @after_proc, block, false),
      ]
    end

    def finish
      BenchmarkCollection.new(@all_definitions).run.each do |benchmark|
        @suite = @suite.add(benchmark)
      end

      @suite.save! if @configuration.record?
      show_comparison if @configuration.compare?
    end

    def show_comparison
      comparisons = Comparison.from_suites(@old_suite, @suite)
      comparisons.each do |comparison|
        puts
        puts comparison.name
        puts comparison.to_plot.map { |s| "  " + s }.join("\n")
      end
    end
  end

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

  class BenchmarkCollection
    def initialize(definitions)
      @definitions = definitions
    end

    def run
      prime_all_definitions
      benchmark_times, definitions = run_benchmarks_once_and_calibrate_repetitions
      remaining_iterations = ITERATIONS - 1

      # The calibration runs serve as the first data points. Now run the rest
      # of the iterations, interleaving them like (1, 2, 3, 1, 2, 3, ...)
      # instead of running each benchmark repeatedly back to back like (1, 1,
      # 1, 2, 2, 2). This spreads any timing jitter out across the suite rather
      # than punishing one benchmark with it.
      definitions = definitions * remaining_iterations
      benchmark_times += definitions.map { |definition| run_definition(definition) }
      assemble_benchmarks_from_times(benchmark_times)
    end

    def prime_all_definitions
      @definitions.each { |definition| Runner.new(definition).prime }
    end

    def run_benchmarks_once_and_calibrate_repetitions
      times = []
      definitions = []
      @definitions.each do |definition|
        time, definition = run_and_determine_repetitions(definition)
        times << time
        definitions << definition
      end

      [times, definitions]
    end

    def run_and_determine_repetitions(definition)
      repetitions = 1
      begin
        times = run_definition(definition, true)
        [times, definition]
      rescue TooSlow
        repetitions *= 2
        definition = definition.with_repetitions(repetitions)
        STDERR.write "!"
        STDERR.flush
        retry
      end
    end

    def assemble_benchmarks_from_times(benchmark_times)
      by_name = benchmark_times.group_by(&:name)
      benchmarks = by_name.map do |name, benchmark_times|
        Benchmark.new(name, benchmark_times.map(&:time))
      end
      put_benchmarks_in_original_order(benchmarks)
    end

    def put_benchmarks_in_original_order(benchmarks)
      names_in_original_order = @definitions.map(&:name)
      benchmarks.sort_by { |benchmark| names_in_original_order.index(benchmark.name) }
    end

    def run_definition(definition, raise_if_too_slow=false)
      STDERR.write "."
      STDERR.flush
      Runner.new(definition, raise_if_too_slow).run
    end
  end

  class TooSlow < RuntimeError
  end

  class Runner
    def initialize(definition, raise_if_too_slow=false)
      @definition = definition
      @raise_if_too_slow = raise_if_too_slow
    end

    def repetitions
      @definition.repetitions
    end

    def prime
      @definition.before_proc.call
      @definition.benchmark_proc.call
      @definition.after_proc.call
    end

    def run
      time = if @definition.enable_gc?
               capture_run_time
             else
               disable_gc { capture_run_time }
             end

      BenchmarkTime.new(@definition.name, time)
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

    def capture_run_time
      @definition.before_proc.call
      time_in_ms = time_proc_with_overhead_nulled_out
      @definition.after_proc.call

      raise TooSlow.new if @raise_if_too_slow && time_in_ms < Ready::MINIMUM_MS

      time_in_ms / repetitions
    end

    def time_proc_with_overhead_nulled_out
      # Compute the actual runtime and the constant time offset imposed by our
      # benchmarking.
      raw_time_in_ms = time_block do
        repetitions.times { @definition.benchmark_proc.call }
      end
      constant_cost = time_block do
        repetitions.times { @definition.nothing_proc.call }
      end
      raw_time_in_ms - constant_cost
    end

    def time_block(&block)
      start = Time.now
      block.call
      end_time = Time.now
      time_in_ms = (end_time - start) * 1000
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
        Benchmark.new(name, times)
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
        [run.name, run.times.to_a]
      end]
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
        "Before: ",
        "After:  ",
        "        ", # legend
      ]
    end

    def bars
      [
        BarRenderer.new(before.times.stats, max_value, bar_length).render,
        BarRenderer.new(after.times.stats, max_value, bar_length).render,
        legend,
      ]
    end

    def legend
      formatted_max = "%.3g" % max_value
      "0" + formatted_max.rjust(bar_length - 1)
    end

    def max_value
      [
        before.times.max,
        after.times.max,
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

      chars = (0...@bar_length).map do |i|
        case
        when i == median
          "X"
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
      value = (value.to_f / @max_value.to_f * @bar_length.to_f).round
      value = [value, @bar_length - 1].min
    end
  end

  class Series
    attr_reader :times

    def initialize(times)
      @times = times
    end

    def to_a
      times
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
      SeriesStatistics.new(min, median, max)
    end

    def stat_string
      "range: %.3f - %.3f ms" % [min, max]
    end
  end

  class SeriesStatistics < Struct.new(:min,
                                      :median,
                                      :max)
  end
end

if $0 == __FILE__
  Ready.main
end
