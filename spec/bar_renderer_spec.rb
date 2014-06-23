require "spec_helper"

module Ready
  describe BarRenderer do
    it "renders only the median when there's room for nothing else" do
      stats = SeriesStatistics.new(1.0, 1.0)
      renderer = BarRenderer.new(stats, 2.0, 10)
      renderer.render.should == "|    X   |"
    end

    it "renders lines connecting the minimum and maximum to the median" do
      stats = SeriesStatistics.new(1.0, 3.0)
      renderer = BarRenderer.new(stats, 4.0, 10)
      renderer.render.should == "|  X---- |"
    end

    it "renders points at zero" do
      stats = SeriesStatistics.new(0.0, 0.0)
      renderer = BarRenderer.new(stats, 10.0, 10)
      renderer.render.should == "|X       |"
    end

    it "renders points at the maximum" do
      stats = SeriesStatistics.new(10.0, 10.0)
      renderer = BarRenderer.new(stats, 10.0, 10)
      renderer.render.should == "|       X|"
    end
  end
end
