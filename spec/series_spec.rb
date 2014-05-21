require "spec_helper"

module Ready
  describe Series do
    let(:series) { Series.new([1.0, 2.0, 100.0, 101.0, 102.0]) }

    it "calculates the median" do
      series.median.should == 100.0
    end

    it "calculates the minimum" do
      series.min.should == 1.0
    end

    it "calculates the maximum" do
      series.max.should == 102.0
    end

    it "calculates percentiles" do
      series.percentile(0).should == 1.0
      series.percentile(12.5).should == 1.5
      series.percentile(25).should == 2.0
      series.percentile(100).should == 102.0
    end
  end
end
