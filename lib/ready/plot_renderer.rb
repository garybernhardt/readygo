module Ready
  class PlotRenderer
    attr_reader :before, :after, :plot_width

    def initialize(before, after, plot_width)
      @before = before
      @after = after
      @plot_width = plot_width
    end

    def render
      titles.zip(bars).map { |title, bar| title + bar }
    end

    def titles
      [
        "Baseline: ",
        "Current:  ",
        "          ", # legend
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
      plot_width - titles.first.length
    end
  end
end
