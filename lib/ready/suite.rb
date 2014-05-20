module Ready
  class Suite
    attr_reader :runs

    def initialize(runs=[])
      @runs = runs
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

    def compare(other_suite)
      names = other_suite.run_names
      names.map do |name|
        Comparison.new(name,
                       self.run_named(name),
                       other_suite.run_named(name))
      end
    end
  end
end
