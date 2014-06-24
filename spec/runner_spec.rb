require "timecop"
require "spec_helper"

module ReadyGo
  describe Runner do
    let(:procs) { BenchmarkProcs.new(Proc.new { }, Proc.new { }, Proc.new { }) }
    let(:definition) { BenchmarkDefinition.new("a definition", procs, :runtime, 1) }
    let(:time) { Time.new(1990, 1, 1, 12, 0, 0) }

    before { Timecop.freeze(time) }
    after { Timecop.return }

    describe "#prime" do
      it "calls each proc once" do
        before_called, benchmark_called, after_called = false, false, false
        procs.before_proc = Proc.new { before_called = true }
        procs.benchmark_proc = Proc.new { benchmark_called = true }
        procs.after_proc = Proc.new { after_called = true }

        Runner.new(definition).prime

        before_called.should == true
        benchmark_called.should == true
        after_called.should == true
      end
    end

    describe "#run" do
      it "records runtime" do
        # Travel seven seconds into the future during the benchmark  for a
        # runtime of around 7000 ms.
        procs.benchmark_proc = lambda { Timecop.travel(time + 7) }
        runtime = Runner.new(definition).run.time
        runtime.should be_within(10.0).of(7000.0)
      end

      it "nulls out benchmarking overhead" do
        # Travel 6 seconds forward during the benchmark and another 5 during
        # the nothing block.
        procs.benchmark_proc = lambda { Timecop.travel(time + 6) }
        procs.nothing_proc = lambda { Timecop.travel(time + 11) }
        Runner.new(definition).run.time.should be_within(10.0).of(1000.0)
      end

      context "when asked to disable GC" do
        before { definition.type = :runtime_without_gc }

        it "disables GC" do
          # GC.disable returns true if the GC is already disabled.
          gc_already_disabled = false
          procs.benchmark_proc = lambda { gc_already_disabled = GC.disable }
          Runner.new(definition).run
          gc_already_disabled.should == true
        end

        it "re-enables the GC even if an exception is raised" do
          procs.benchmark_proc = lambda { raise DummyException.new }
          begin
            Runner.new(definition).run
          rescue DummyException
          end
          # GC.enable returns false if the GC is already enabled.
          GC.enable.should == false
        end
      end

      context "when asked to record GC time" do
        it "records only GC time, not total execution time" do
          definition.type = :gc_time
          procs.benchmark_proc = lambda do
            # Generate a lot of garbage
            10000.times { |i| [i.to_s * 100] }
            # Spend five seconds here; we shouldn't see this time reported.
            Timecop.travel(time + 5)
          end
          runtime = Runner.new(definition).run.time
          # We should see a small, but nonzero, GC time (far less than 1ms)
          runtime.should be_within(1.0).of(1.0)
        end
      end

      context "when the benchmark definition has an unknown type" do
        it "raises an exception" do
          definition.type = :an_unknown_type
          message = "BUG: don't know how to record benchmark type :an_unknown_type"
          expect do
            Runner.new(definition).run
          end.to raise_error(RuntimeError, message)
        end
      end

      context "when asked to enforce minimum runtime" do
        it "raises if the benchmark is too fast" do
          expect do
            Runner.new(definition, true).run
          end.to raise_error(Runner::BenchmarkTooFast)
        end

        it "doesn't raise if the benchmark is slow enough" do
          procs.benchmark_proc = lambda { Timecop.travel(time + 1) }
          Runner.new(definition, true).run
        end
      end
    end
  end
end

class DummyException < RuntimeError; end
