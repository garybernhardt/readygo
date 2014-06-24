module ReadyGo
  class BarRenderer
    def initialize(series_statistics, max_value, bar_length)
      @statistics = series_statistics
      @max_value = max_value
      # Make room for pipes that we'll add to either side of the bar
      @bar_length = bar_length - 2
    end

    def render
      min = scale_value(@statistics.min)
      percentile_80 = scale_value(@statistics.percentile_80)

      chars = (0...@bar_length).map do |i|
        case
        when i == min
          "X"
        when i >= min && i <= percentile_80
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
end
