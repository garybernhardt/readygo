module Ready
  class Suite
    attr_reader :runs

    def initialize(runs=[])
      @runs = runs
    end

    def self.load
      old_results = JSON.parse(File.read(".readygo"))
      runs = old_results.each_pair.map do |name, times|
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
      File.write(".readygo", JSON.dump(to_hash))
    end

    def to_hash
      Hash[runs.map do |run|
        [run.name, run.times.to_a]
      end]
    end
  end
end
