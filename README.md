# Readygo

Readygo is a benchmarking tool that's unique in several ways:

* It goes to great lengths to produce accurate numbers by nulling out sources of timing offsets and jitter.
(See [Timing Methodology](#timing-methodology) below.)

* It can reliably measure aggregate GC costs to sub-nanosecond accuracy (that's less than one CPU cycle per benchmark run).

* It's pretty fast if your benchmark is fast.
For a benchmark taking about 1ms, a full run will take around half a second.

* It draws text plots right at the terminal so your flow isn't broken.

* It records benchmark runtime, stores it in a file, and compares it to benchmark runs that you make after changing the code.
Most benchmarking tools are designed for comparison of multiple alternatives in the same source tree, which usually requires more effort.

It's possible to make much faster measurements with other tools, but their results can be deceiving.
If you simply time two pieces of code, how do you know that a burst of IO from another process didn't slow one of them down?
What if a GC run kicks in while running the second code, and it includes some garbage (and hence time cost) from the first code?
How do you know that your benchmark was long enough to get accurate timing from the system clock?
How much constant and variable overhead does your benchmarking harness itself add, and can that overhead mask results?
Etc., etc.
Readygo compensates for all of these problems (see [Timing Methodology](#timing-methodology) below) and it can reliably measure even sub-nanosecond aggregate performance costs (see [Sub-Nanosecond Timing Example](#sub-nanosecond-timing-example) below).

## Basic Usage

Benchmarks are defined with a simple block-based syntax:

```ruby
# mybenchmark.rb
ready "big files" do
  before do
    File.write("foo", "X" * 10 ** 6)
  end

  after do
    File.delete("foo")
  end

  go "being read" do
    File.read("foo")
  end
end
```

The `before` and `after` blocks do setup and teardown.
Their cost is not included in the reported benchmarks.
There can be many `go` blocks, each of which will be reported individually.

To record the system's current performance as a baseline, run:

```
readygo --record mybenchmark.rb
```

The recorded timings are written to a JSON file called `.readygo` and will serve as a baseline for subsequent runs.
To make a benchmark comparison against other branches, changes that you make, etc., run:

```
readygo --compare mybenchmark.rb
```

This will load the recorded baseline benchmark numbers, re-run the benchmarks against the current code, and compare.
It will look something like this:

```
.!.!.!.!.!.!.!.!................
big files being read
  Baseline: |                       X--------------                            |
  Current:  |                                              X-------------------|
            0                                                            8.56 ms
```

The line of dots and bangs is a progress indicator to let you know that it's still alive.
Dots represent benchmarks being run; bangs represent benchmarks that were too fast and were wrapped in loops automatically to increase their runtime (see [Timing Methodology](#timing-methodology) for more on that).
Times are expressed in seconds (s), milliseconds (ms), microseconds (us), or nanoseconds (ns) as appropriate.

The plot shows a rough visual indication of performance differences between the last recording ("Baseline") and the current system ("Current").
It provides the best estimate of actual runtime cost (the X, which is the lowest sampled runtime), as well as a visual indication of the variance (the bar to the right of the X, which extends until the 80th percentile of runtime).

## Usage Tips

* Accuracy will be best when nothing else is running on the machine, especially high-load processes like backups.
This is true for any benchmarking tool.

* Implementing multiple variations of a piece of code is rarely necessary.
Instead, `readygo --record` the current benchmark performance, make your changes to the code (or switch branches), then `readygo --compare` to see how your changes affected the benchmarks.

* Move as much as possible into `before` and `after` blocks.
Generally, the `go` block should be a single method call.
This ensures that you're benchmarking only one thing.

## Garbage Collector Benchmarks

The `go` method can take some options to do GC analysis:

* `go :without_gc => true` adds a second benchmark with the garbage collector disabled.
The original benchmark with GC will still be run.

* `go :gc_time => true` will run the benchmark and report only the time that was spent in the garbage collector using Ruby's built-in GC profiler.
This will take much longer than a normal benchmark.
It needs to run the benchmark many times to spend a lot of time in the garbage collector.

These options can be used together.
With both GC options enabled, the output will contain the standard benchmark of runtime, the runtime with GC disabled, and the time spent in the GC:

```
big files being read
  Baseline: |                       X------------------------------------------|
  Current:  |                                     X----------------------      |
            0                                                            8.56 ms

big files being read (GC Disabled)
  Baseline: |                                          X-----------------------|
  Current:  |                                          X---------------------- |
            0                                                            8.12 ms

big files being read (GC Time)
  Baseline: |                                                  X---------------|
  Current:  |                                                 X-----------     |
            0                                                              19 us
```

## Timing Methodology

Readygo nulls out timing offsets and jitter in the following ways:

* The before and after blocks are repeated for each benchmark iteration.

* The before, after, and benchmark blocks are each called once before any measurement begins.
This lets the system do any one-time initialization that will be triggered by the benchmark.
It also warms the CPU cache, disk cache, Ruby's small object cache, etc.

* Benchmarks are run 16 times each in an interleaved pattern.
If there are three benchmarks in the suite, they'll be run in a pattern of "1, 2, 3, 1, 2, 3, ..." as opposed to "1, 1, 1, ..., 2, 2, 2, ...".
The interleaved pattern is less sensitive to jitter.
A transient timing event like disk IO or CPU contention would normally disrupt the currently-running benchmark.
By interleaving benchmarks, the transient event's effect is spread out across the suite.
It will often be invisible in the output because the UI shows the 80th percentile of samples, not the maximum runtime.

* A fresh GC run is triggered before each iteration of each benchmark.
This is by far the largest expense for small benchmarks, tripling the runtime.
It's also necessary: otherwise, GC runs will trigger unreliably and add jitter to the timing.
There may still be GC runs during the benchmark, but they will be fairly deterministic and will only show up in large benchmarks where their costs amortize nicely.

* If a benchmark takes less than 1 ms, it's re-run in a loop that runs it twice.
If that takes less than 1 ms, the loop is doubled to four times, and this is repeated until the loop takes at least 1 ms.
This ensures that the timing stays well above the resolution of the system's clock.
On OS X, that resolution is about 2 us, so the 1 ms minimum is 500 times the clock's resolution, ensuring that we get meaningful time measurements.

* Readygo's own benchmarking overhead is nulled out.
After each benchmark block is run, the full benchmarking process is repeated, but with an empty block.
The empty block gets the full treatment, including its own fresh GC run before starting.
That tells us how long the Readygo machinery itself took to execute, which is then subtracted from the benchmark runtime.
This also nulls out the added overhead of the implicit loops described above, which can reach a thousand or more iterations pretty easily.
It's not perfect (for example, there may be minor GC effects that can't be nulled out), but it's quite good, and certainly better than other benchmarking methods that are used commonly in Ruby.

## Sub-Nanosecond Timing Example

Readygo's measurement strategy results in very accurate readings.
Consider this benchmark of a single-element array being created:

```ruby
ready "an array" do
  go "of a single integer", :gc_time => true do
    [1]
  end
end
```

Readygo can make meaningful measurements of even this tiny bit of code.
The GC timing output is:

```
an array of a single integer (GC Time)
  Baseline: |                                              X-------------------|
  Current:  |                                             X-------------       |
            0                                                            .024 ns
```

The block takes about 0.02 nanoseconds of GC time per iteration, which is far less than a single CPU clock cycle (it's about six light-millimeters of time).
While running this benchmark, Readygo scaled up to running the block in a loop 524,288 times, which was enough to trigger a GC run costing about .026 ms.
The benchmarking overhead's GC cost of .014 ms was subtracted from that, for a net measured time of about .012 ms.
Dividing .012 ms by the 524,288 iterations gives a GC time of roughly .02 ns per block call, which what you see reported.
In aggregate, each `[1]` array constructed eventually costs around .02 ns in garbage collection time.

Readygo can reliably benchmark on sub-nanosecond timescales.
Running this benchmark multiple times will produce very similar numbers; it's always around 0.02 ns.
You probably won't need to do this, and it's strange to think about, but hopefully it gives you some confidence.
No benchmark is too small to measure, so you're free to microbenchmark your four-line methods by themselves.
No need to even put a loop around them; Readygo will take care of that if it needs to.

Note that I reduced the minimum benchmark duration to 0.01 ms here to make it bearable.
It's a pathological case, after all.
This reduces accuracy if anything, so it doesn't affect the conclusion.

Finally: if we replace the `[1]` with an empty block, Readygo scales up to millions of iterations and the resulting plots simply contain noise, as expected.
The `[1]` really is being measured.
