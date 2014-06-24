require "spec_helper"

module ReadyGo
  describe BenchmarkDefinition do
    it "raises an exception when the benchmark type is invalid" do
      expect do
        BenchmarkDefinition.new("a benchmark", nil, :invalid_benchmark_type)
      end.to raise_error("BUG: unknown benchmark type :invalid_benchmark_type")
    end
  end
end
