require "spec_helper"

module Ready
  describe Statistics do
    let(:values) { [1.0, 2.0, 100.0, 101.0, 102.0] }

    it "calculates percentiles" do
      Statistics.percentile(values, 0).should == 1.0
      Statistics.percentile(values, 50).should == 100
      Statistics.percentile(values, 62.5).should == 100.5
      Statistics.percentile(values, 80).should == 101.2
      Statistics.percentile(values, 100).should == 102.0
    end
  end
end
