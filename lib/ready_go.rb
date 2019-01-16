require "json"
require "optparse"
require "forwardable"

require_relative "ready_go/application"
require_relative "ready_go/configuration"
require_relative "ready_go/context"
require_relative "ready_go/values"
require_relative "ready_go/benchmark_collection"
require_relative "ready_go/runner"
require_relative "ready_go/suite"
require_relative "ready_go/plot_renderer"
require_relative "ready_go/bar_renderer"
require_relative "ready_go/serializer"
require_relative "ready_go/statistics"
require_relative "ready_go/benchmark_definition"
require_relative "ready_go/time_formatting"

module ReadyGo
  ITERATIONS = 16
  # For comparison, on OS X Mavericks Time.now seems to have a resolution of
  # about 2 us.
  MINIMUM_MS = 1
  RECORDING_FILE_NAME = ".readygo"
  FILE_FORMAT_VERSION = 1
  SCREEN_WIDTH = 80

  class << self
    def application
      @application ||= Application.new
    end
  end

  def self.main
    application.run
  end
end
