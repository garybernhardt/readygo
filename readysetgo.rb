require "pp"
require "json"
require "optparse"
require "forwardable"
require_relative "lib/ready"

def ready(name, &block)
  Ready.add_context(name, &block)
end

module Ready
  ITERATIONS = 16
  # For comparison, on OS X Mavericks Time.now seems to have a resolution of
  # about 2 us.
  MINIMUM_MS = 1
  RECORDING_FILE_NAME = ".readygo"
  FILE_FORMAT_VERSION = 1
  SCREEN_WIDTH = 80

  def self.main
    old_suite = Serializer.load
    load_files(configuration.files)
    suite = self.suite
    Context.all.each { |context| suite = context.finish(suite) }
    show_comparison(old_suite, suite) if configuration.compare?
    Serializer.save!(suite) if configuration.record?
  end

  def self.suite
    @suite ||= Suite.new
  end

  def self.show_comparison(old_suite, new_suite)
    comparisons = old_suite.compare(new_suite)
    plot_width = SCREEN_WIDTH - 2
    comparisons.each do |comparison|
      puts
      puts comparison.name
      puts comparison.to_plot(plot_width).map { |s| "  " + s }.join("\n")
    end
  end

  def self.add_context(name, &block)
    name = name.to_s
    load_files(configuration.files)
    context = Context.new(name, configuration)
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
end

if $0 == __FILE__
  Ready.main
end
