require "pp"
require "json"
require "optparse"
require_relative "lib/ready"

def ready(name, &block)
  Ready.add_context(name, &block)
end

module Ready
  ITERATIONS = 16
  MINIMUM_MS = 1

  def self.main
    load_files(configuration.files)
    Context.all.each { |context| context.finish }
  end

  def self.add_context(name, &block)
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
end

if $0 == __FILE__
  Ready.main
end
