module ReadyGo
  class BenchmarkDefinition < Struct.new(:name,
                                         :procs,
                                         :type,
                                         :repetitions)

    TYPES = [:runtime, :runtime_without_gc, :gc_time]

    extend Forwardable
    delegate :before_proc => :procs
    delegate :after_proc => :procs
    delegate :benchmark_proc => :procs
    delegate :nothing_proc => :procs

    def initialize(name, procs, type, repetitions=1)
      raise "BUG: unknown benchmark type #{type.inspect}" unless TYPES.include?(type)
      super(name, procs, type, repetitions)
    end

    def enable_gc?
      type != :runtime_without_gc
    end

    def record_runtime?
      [:runtime, :runtime_without_gc].include?(type)
    end

    def record_gc_time?
      type == :gc_time
    end

    def with_repetitions(repetitions)
      BenchmarkDefinition.new(name, procs, type, repetitions)
    end
  end
end
