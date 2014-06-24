module ReadyGo
  class Serializer
    def self.load
      begin
        serialized = JSON.parse(File.read(".readygo"))
      rescue Errno::ENOENT
        return new
      end

      version = serialized.fetch("readygo_file_format_version")
      unless version == ReadyGo::FILE_FORMAT_VERSION
        raise "Cowardly refusing to load .readygo file in old format. Please delete it!"
      end
      benchmark_results = serialized.fetch("benchmark_results").map do |name, times|
        BenchmarkResult.new(name, times)
      end
      Suite.new(benchmark_results)
    end

    def self.save!(suite)
      File.write(".readygo", JSON.dump(suite_to_primitives(suite)))
    end

    def self.suite_to_primitives(suite)
      benchmark_results = suite.benchmark_results.map do |result|
        [result.name, result.times.to_a]
      end
      {
        "readygo_file_format_version" => ReadyGo::FILE_FORMAT_VERSION,
        "benchmark_results" => benchmark_results
      }
    end
  end
end
