module Ready
  class BenchmarkCollection
    def initialize(definitions)
      @definitions = definitions
    end

    def run
      prime_all_definitions
      benchmark_times, definitions = run_benchmarks_once_and_calibrate_repetitions
      remaining_iterations = ITERATIONS - 1

      # The calibration runs serve as the first data points. Now run the rest
      # of the iterations, interleaving them like (1, 2, 3, 1, 2, 3, ...)
      # instead of running each benchmark repeatedly back to back like (1, 1,
      # 1, 2, 2, 2). This spreads any timing jitter out across the suite rather
      # than punishing one benchmark with it.
      definitions = definitions * remaining_iterations
      benchmark_times += definitions.map { |definition| run_definition(definition) }
      assemble_benchmarks_from_times(benchmark_times)
    end

    def prime_all_definitions
      @definitions.each { |definition| Runner.new(definition).prime }
    end

    def run_benchmarks_once_and_calibrate_repetitions
      times = []
      definitions = []
      @definitions.each do |definition|
        time, definition = run_one_benchmark_and_calibrate_repetitions(definition)
        times << time
        definitions << definition
      end

      [times, definitions]
    end

    def run_one_benchmark_and_calibrate_repetitions(definition)
      repetitions = 1
      begin
        times = run_definition(definition, true)
        [times, definition]
      rescue Runner::TooSlow
        repetitions *= 2
        definition = definition.with_repetitions(repetitions)
        STDERR.write "!"
        STDERR.flush
        retry
      end
    end

    def assemble_benchmarks_from_times(benchmark_times)
      by_name = benchmark_times.group_by(&:name)
      benchmarks = by_name.map do |name, benchmark_times|
        Benchmark.new(name, benchmark_times.map(&:time))
      end
      put_benchmarks_in_original_order(benchmarks)
    end

    def put_benchmarks_in_original_order(benchmarks)
      names_in_original_order = @definitions.map(&:name)
      benchmarks.sort_by { |benchmark| names_in_original_order.index(benchmark.name) }
    end

    def run_definition(definition, raise_if_too_slow=false)
      STDERR.write "."
      STDERR.flush
      Runner.new(definition, raise_if_too_slow).run
    end
  end
end
