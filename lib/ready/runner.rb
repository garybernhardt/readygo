module Ready
  class Runner
    def initialize(definition, raise_if_too_slow=false)
      @definition = definition
      @raise_if_too_slow = raise_if_too_slow
    end

    def repetitions
      @definition.repetitions
    end

    def prime
      @definition.before_proc.call
      @definition.benchmark_proc.call
      @definition.after_proc.call
    end

    def run
      time = if @definition.enable_gc?
               capture_run_time
             else
               disable_gc { capture_run_time }
             end

      BenchmarkTime.new(@definition.name, time)
    end

    def disable_gc
      # Get as clean a GC state as we can before benchmarking
      GC.start

      GC.disable
      yield
    ensure
      GC.enable
      GC.start
    end

    def capture_run_time
      @definition.before_proc.call
      time_in_ms = time_proc_with_overhead_nulled_out
      @definition.after_proc.call

      raise TooSlow.new if @raise_if_too_slow && time_in_ms < Ready::MINIMUM_MS

      time_in_ms / repetitions
    end

    def time_proc_with_overhead_nulled_out
      # Compute the actual runtime and the constant time offset imposed by our
      # benchmarking.
      raw_time_in_ms = time_block do
        repetitions.times { @definition.benchmark_proc.call }
      end
      constant_cost = time_block do
        repetitions.times { @definition.nothing_proc.call }
      end
      raw_time_in_ms - constant_cost
    end

    def time_block(&block)
      start = Time.now
      block.call
      end_time = Time.now
      time_in_ms = (end_time - start) * 1000
    end

    class TooSlow < RuntimeError
    end
  end
end
