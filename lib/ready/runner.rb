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
      if @definition.record_runtime?
        time_runtime(&block)
      elsif @definition.record_gc_time?
        time_gc_time(&block)
      else
        raise "BUG: didn't know how to record benchmark definition #{@definition}"
      end
    end

    def time_runtime(&block)
      # Get a clean GC state
      GC.start

      start = Time.now
      block.call
      end_time = Time.now
      time_in_ms = (end_time - start) * 1000
    end

    def time_gc_time(&block)
      # Get a clean GC state
      GC.start

      # Clear the GC profiler so we get correct stats
      GC::Profiler.enable
      GC::Profiler.clear

      block.call

      # Trigger a GC run while the GC profiler is still on. This ensures that
      # we count the GC cost of any uncollected garbage left around by the
      # benchmark.
      GC.start

      gc_time_in_ms = GC::Profiler.total_time
      GC::Profiler.disable

      p [repetitions, gc_time_in_ms]
      gc_time_in_ms
    end

    class TooSlow < RuntimeError
    end
  end
end
