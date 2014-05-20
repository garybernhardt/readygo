module Ready
  class Serializer
    def self.load
      begin
        serialized = JSON.parse(File.read(".readygo"))
      rescue Errno::ENOENT
        return new
      end

      version = serialized.fetch("readygo_file_format_version")
      unless version == Ready::FILE_FORMAT_VERSION
        raise "Cowardly refusing to load .readygo file in old format. Please delete it!"
      end
      runs = serialized.fetch("runs").map do |name, times|
        Benchmark.new(name, times)
      end
      Suite.new(runs)
    end

    def self.save!(suite)
      File.write(".readygo", JSON.dump(suite_to_primitives(suite)))
    end

    def self.suite_to_primitives(suite)
      runs = suite.runs.map do |run|
        [run.name, run.times.to_a]
      end
      {
        "readygo_file_format_version" => Ready::FILE_FORMAT_VERSION,
        "runs" => runs
      }
    end
  end
end
