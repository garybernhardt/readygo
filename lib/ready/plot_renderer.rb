module Ready
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
end
