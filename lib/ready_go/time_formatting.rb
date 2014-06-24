module ReadyGo
  module TimeFormatting
    def self.format_duration(duration)
      if duration < 10.0 ** -6
        duration *= 10 ** 9
        units = "ns"
      elsif duration < 10.0 ** -3
        duration *= 10 ** 6
        units = "us"
      elsif duration < 1.0
        duration *= 10 ** 3
        units = "ms"
      else
        units = "s"
      end

      "%.3f %s" % [duration, units]
    end
  end
end
