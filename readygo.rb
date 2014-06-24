require_relative "lib/ready"

def ready(name, &block)
  Ready.application.add_context(name, &block)
end

module Ready
  class << self
    attr_reader :application
  end

  def self.main
    @application = Application.new
    @application.run
  end

  class Application
    def initialize
      @contexts = []
    end

    def run
      old_suite = Serializer.load
      load_files(configuration.files)
      suite = Suite.new
      definitions = @contexts.map(&:definitions).flatten
      BenchmarkCollection.new(definitions).run.each do |benchmark_result|
        suite = suite.add(benchmark_result)
      end

      show_comparison(old_suite, suite) if configuration.compare?
      Serializer.save!(suite) if configuration.record?
    end

    def show_comparison(old_suite, new_suite)
      comparisons = old_suite.compare(new_suite)
      plot_width = SCREEN_WIDTH - 2
      comparisons.each do |comparison|
        plot = PlotRenderer.new(comparison, plot_width).render
        puts
        puts comparison.name
        puts plot.map { |s| "  " + s }.join("\n")
      end
    end

    def add_context(name, &block)
      name = name.to_s
      load_files(configuration.files)
      context = Context.new(name)
      context.instance_eval(&block)
      @contexts << context
    end

    def configuration
      @configuration ||= Configuration.parse_options(ARGV)
    end

    def load_files(files)
      $LOAD_PATH.unshift "."
      files.each { |file| require file }
    end
  end
end

if $0 == __FILE__
  Ready.main
end
