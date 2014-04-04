require "pp"
require "json"

def ready(name, &block)
  name = name.to_s
  record = ARGV.include?("--record")
  if (index = ARGV.index("--iterations"))
    iterations = ARGV[index + 1].to_i
  else
    iterations = 16
  end
  ready = Ready.new(name, iterations, record)
  ready.instance_eval(&block)
  ready.finish
end

at_exit { Ready.show_comparison if ARGV.include?('--compare') }

class Ready
  class << self
    def suite
      @suite ||= Suite.new
    end
  end

  def initialize(name, iterations, record)
    @name = name
    @set_block = lambda { }
    @after_block = lambda { }
    @iterations = iterations
    @record = record
  end

  def set(&block)
    @set_block = block
  end

  def after(&block)
    @after_block = block
  end

  def go(name, &go_block)
    # Prime
    @set_block.call
    go_block.call

    STDERR.write "#{@name} #{name} "

    normal = run(go_block, true)
    no_gc = run(go_block, false)
    self.class.suite.add(RunResult.new(@name + " " + name, normal, no_gc))

    STDERR.puts
  end

  def finish
    dump_results if @record
  end

  def dump_results
    File.write(".readygo", JSON.dump(self.class.suite.to_hash))
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
        RunResult.new(name, normal_times, no_gc_times)
      end
      new(runs)
    end

    def add(run)
      @runs << run
    end

    def run_names
      @runs.map(&:name)
    end

    def run_named(name)
      run = @runs.find { |run| run.name == name }
      run or raise "Couldn't find run: #{name.inspect}"
    end

    def to_hash
      Hash[runs.map do |run|
        [run.name, [run.normal.times, run.without_gc.times]]
      end]
    end
  end

  class Table
    def initialize(rectangle)
      @rectangle = rectangle
    end

    def count
      @rectangle.count
    end

    def first
      @rectangle.first
    end

    def select(params)
      result = @rectangle
      params.each do |key, value|
        result = result.select { |row| row.send(key) == value }
      end
      Table.new(result)
    end

    def find(params)
      rect = select(params)
      if rect.count == 1
        rect.first
      else
        raise "Table#find found #{rect.count} results for #{params.inspect}"
      end
    end

    def row_values(row_name)
      @rectangle.map(&row_name).uniq
    end
  end

  class DataPoint < Struct.new(:experiment_name,
                               :run_name,
                               :run_type,
                               :min,
                               :percentile_25,
                               :median,
                               :percenile_75,
                               :max)
  end

  def self.show_comparison
    old_suite = Suite.load
    new_suite = self.suite
    comparisons = Comparison.from_suites(old_suite, new_suite)
    comparisons.each do |comparison|
      puts comparison.name
      puts comparison.to_plot.map { |s| "  " + s }.join("\n")
    end
  end

  def run(go_block, allow_gc=true)
    times = []
    gc_times = []

    (0...@iterations).each do
      @set_block.call

      # Get as clean a GC state as we can before benchmarking
      GC.start

      GC.disable unless allow_gc
      start = Time.now
      go_block.call
      end_time = Time.now
      time_in_ms = (end_time - start) * 1000
      times << time_in_ms
      GC.enable unless allow_gc
      GC.start unless allow_gc

      @after_block.call

      STDERR.write "."
      STDERR.flush
    end

    times
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
      PlotRenderer.new(self).render
    end
  end

  class PlotRenderer
    SCREEN_WIDTH = 80

    def initialize(comparison, screen_width=SCREEN_WIDTH)
      @comparison = comparison
      @screen_width = screen_width
    end

    def before; @comparison.before; end
    def after; @comparison.after; end
    def screen_width; @screen_width; end

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
        BarRenderer.new(before.normal, max_value, bar_length).render,
        BarRenderer.new(before.without_gc, max_value, bar_length).render,
        BarRenderer.new(after.normal, max_value, bar_length).render,
        BarRenderer.new(after.without_gc, max_value, bar_length).render,
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
    def initialize(series, max_value, bar_length)
      @series = series
      @max_value = max_value
      # Make room for pipes that we'll add to either side of the bar
      @bar_length = bar_length - 2
    end

    def render
      min = scale_value(@series.min)
      median = scale_value(@series.median)
      max = scale_value(@series.max)

      min_width = min
      median_width = median - min
      max_width = max - median

      # Make room for median marker
      if median_width == 0
        min_width -= 1
      else
        median_width -= 1
      end

      (
        "|" +
        (" " * min_width) +
        ("-" * median_width) +
        "*" +
        ("-" * max_width) +
        (" " * (@bar_length - max)) +
        "|"
      )
    end

    def scale_value(value)
      (value.to_f / @max_value.to_f * @bar_length.to_f).round
    end
  end

  class RunResult
    attr_reader :name, :normal, :without_gc

    def initialize(name, normal_times, no_gc_times)
      @name = name
      @normal = Series.new(normal_times)
      @without_gc = Series.new(no_gc_times)
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

    def stat_string
      "range: %.3f - %.3f ms" % [min, max]
    end
  end
end
