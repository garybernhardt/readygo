module Ready
  class Suite
    attr_reader :benchmark_results

    def initialize(benchmark_results=[])
      @benchmark_results = benchmark_results
    end

    def add(benchmark_result)
      Suite.new(@benchmark_results + [benchmark_result])
    end

    def benchmark_names
      @benchmark_results.map(&:name)
    end

    def benchmark_result_named(name)
      benchmark_result = @benchmark_results.find { |result| result.name == name }
      benchmark_result or raise BenchmarkNotFound.new(name)
    end

    def compare(other_suite)
      names = other_suite.benchmark_names
      names.map do |name|
        Comparison.new(name,
                       self.benchmark_result_named(name),
                       other_suite.benchmark_result_named(name))
      end
    end

    class BenchmarkNotFound < RuntimeError
    end
  end
end
