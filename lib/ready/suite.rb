module Ready
  class Suite
    attr_reader :runs

    def initialize(runs=[])
      @runs = runs
    end

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
      new(runs)
    end

    def add(run)
      Suite.new(@runs + [run])
    end

    def run_names
      @runs.map(&:name)
    end

    def run_named(name)
      run = @runs.find { |run| run.name == name }
      run or raise "Couldn't find run: #{name.inspect}"
    end

    def save!
      File.write(".readygo", JSON.dump(to_primitives))
    end

    def to_primitives
      runs = self.runs.map do |run|
        [run.name, run.times.to_a]
      end
      {
        "readygo_file_format_version" => Ready::FILE_FORMAT_VERSION,
        "runs" => runs
      }
    end
  end
end
