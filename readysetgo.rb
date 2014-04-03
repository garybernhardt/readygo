require "pp"
require "json"

HTML_TEMPLATE = <<-htmlend
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="content-type" content="text/html; charset=utf-8"/>
    <title>
      readysetgo
    </title>
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.10.1/jquery.min.js"></script>
    <script src="http://code.highcharts.com/highcharts.js"></script>
    <script src="http://code.highcharts.com/highcharts-more.js"></script>
    <script type="text/javascript">
      $(function() {
        var i;

        var all_data = %s;

        for (i=0; i<all_data.length; i++) {
          var series_data = all_data[i].series_data;
          var title = all_data[i].title;
          console.log(series_data);
          div = $('<div class="chart_div"></div>').appendTo("body").get()[0];
          $(div).highcharts({
            chart: { type: 'boxplot' },
            title: { text: title },
            yAxis: { min: 0 },
            series: series_data,
          });
        }
      });
    </script>
    <style>
      .chart_div {
        width: 700px;
        height: 300px;
      }
      .chart_div {
        margin: 20px;
      }
    </style>
  </head>
  <body></body>
</html>
htmlend

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
    new_suite = self.suite
    old_suite = Suite.load
    run_names = new_suite.runs.map(&:name)

    chart_data = run_names.map do |run_name|
      ["Old", "New"].zip([old_suite, new_suite]).map do |experiment_name, suite|
        run = suite.run_named(run_name)
        ["Normal", "Without GC"].zip([run.normal, run.without_gc]).map do |run_type, series|
          DataPoint.new(experiment_name,
                        run_name,
                        run_type,
                        series.min,
                        series.percentile(25),
                        series.median,
                        series.percentile(75),
                        series.max)
        end
      end
    end.flatten

    table = Table.new(chart_data)

    chart_data = table.row_values(:run_name).map do |run_name|
      result_for_run(table, run_name)
    end

    File.write("temp.html", HTML_TEMPLATE % chart_data.to_json)
    `open temp.html`
  end

  def self.result_for_run(table, run_name)
    run_types = ["Normal", "Without GC"]

    run_data = run_types.map do |run_type|
      run_type_data = table.row_values(:experiment_name).map do |experiment_name|
        row = table.find(:run_name => run_name,
                         :experiment_name => experiment_name,
                         :run_type => run_type)
        [row.min,
         row.percentile_25,
         row.median,
         row.percenile_75,
         row.max]
      end
      {
        :name => run_type,
        :data => run_type_data,
      }
    end
    {
      :title => run_name,
      :series_data => run_data,
    }
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

def ten_years_of_price_points
  generate_price_points(Day.new(2000, 1, 3), Day.new(2010, 1, 1))
end

def one_year_of_price_points
  generate_price_points(Day.new(2000, 1, 3), Day.new(2001, 1, 1))
end

def generate_price_points(first_day, last_day)
  Hash[
    Day::Range.new(first_day, last_day).map do |day|
      [day, Assets::Fund::PricePoint.new(1.0)]
    end
  ]
end

