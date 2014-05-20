require "spec_helper"

module Ready
  describe Suite do
    let(:result) { BenchmarkResult.new("a benchmark", [1.0, 2.0]) }

    it "adds benchmark results" do
      Suite.new.add(result).benchmark_results.should == [result]
    end

    it "knows its benchmarks' names" do
      Suite.new.add(result).benchmark_names.should == ["a benchmark"]
    end

    describe "finding benchmarks by name" do
      it "finds benchmarks by name" do
        Suite.new.add(result).benchmark_result_named("a benchmark").should == result
      end

      it "raises an exception when it can't find a benchmark" do
        expect do
          Suite.new.benchmark_result_named("a missing benchmark")
        end.to raise_error(Suite::BenchmarkNotFound, "a missing benchmark")
      end
    end

    it "compares results to other suites" do
      result1 = BenchmarkResult.new("a benchmark", [1.0, 2.0])
      result2 = BenchmarkResult.new("a benchmark", [2.0, 3.0])
      suite1 = Suite.new([result1])
      suite2 = Suite.new([result2])
      comparison = suite1.compare(suite2)
      comparison.should == [Comparison.new("a benchmark", result1, result2)]
    end

    it "warns about duplicate benchmark names"
  end
end
