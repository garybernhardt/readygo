module ReadyGo
  class PlotRenderer
    attr_reader :before, :after, :plot_width

    def initialize(comparison, plot_width)
      @before = comparison.before
      @after = comparison.after
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
        BarRenderer.new(before.stats, max_value, bar_length).render,
        BarRenderer.new(after.stats, max_value, bar_length).render,
        legend,
      ]
    end

    def legend
      max = TimeFormatting.format_duration(max_value)
      "0" + max.rjust(bar_length - 1)
    end

    def max_value
      [
        before.stats.percentile_80,
        after.stats.percentile_80
      ].max
    end

    def bar_length
      plot_width - titles.first.length
    end
  end
end
