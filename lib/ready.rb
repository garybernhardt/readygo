require "json"
require "optparse"
require "forwardable"

require_relative "ready/configuration"
require_relative "ready/context"
require_relative "ready/values"
require_relative "ready/benchmark_collection"
require_relative "ready/runner"
require_relative "ready/suite"
require_relative "ready/plot_renderer"
require_relative "ready/bar_renderer"
require_relative "ready/serializer"
require_relative "ready/statistics"
require_relative "ready/benchmark_definition"

module Ready
  ITERATIONS = 16
  # For comparison, on OS X Mavericks Time.now seems to have a resolution of
  # about 2 us.
  MINIMUM_MS = 1
  RECORDING_FILE_NAME = ".readygo"
  FILE_FORMAT_VERSION = 1
  SCREEN_WIDTH = 80
end
