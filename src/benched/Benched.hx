/*
 * Apache License, Version 2.0
 *
 * Copyright (c) 2020 Kenton Hamaluik
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at:
 *     http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package benched;

import haxe.ds.ArraySort;
import haxe.Json;
import haxe.Timer;
import haxe.ds.StringMap;
using Lambda;
using StringTools;
 
/**
 Utility to run benchmarks and collect samples
**/
class Benched {
    /**
     How long a process must take to count as a sample. If the sample takes
     less time than this, it will be repeated until it this time is completed
    **/
    var minSecondsPerSample: Float;
 
    /**
     How many samples we must collect from each benchmark until we are satisfied
     that we have a respresentative population
    **/
    var samplesPerBenchmark: Int;
 
    /**
     All our benchmarks
    **/
    var benchmarks: StringMap<BenchmarkResults>;
 
    /**
     Whether or not to print progress information
    **/
    var verbose: Bool;
 
    /**
     Create a new benchmark suite
     @param minSecondsPerSample how much time must accumulate by repeating the benchmark until a sample is counted
     @param samplesPerBenchmark how many samples to collect per benchmark
     @param verbose whether or not to print progress information
    **/
    public function new(minSecondsPerSample: Float = 0.5, samplesPerBenchmark: Int = 50, verbose: Bool = false) {
        this.minSecondsPerSample = minSecondsPerSample;
        this.samplesPerBenchmark = samplesPerBenchmark;
        this.verbose = verbose;
        this.benchmarks = new StringMap();
    }
 
    inline function stamp(): Float {
        #if (sys || hxnodejs)
        return Sys.cpuTime();
        #else
        return Timer.stamp();
        #end
    }
 
    function print(s: String): Void {
        #if (sys || hxnodejs)
        Sys.print(s);
        #elseif js
        js.html.Console.log(s);
        #else
        trace(s);
        #end
    }

    function println(s: String): Void {
        #if (sys || hxnodejs)
        Sys.println(s);
        #elseif js
        js.html.Console.log(s);
        #else
        trace(s);
        #end
    }

    /**
    Benchmark the function `f`, storing the results to be processed later.
    **Note**: `f` should be _as pure as possible_, because it will be run
    numerous times so as to collect enough sampling data
    @param name the name of the benchmark
    @param f a callback to benchmark with
    @return BenchmarkResults
    **/
    public function benchmark(name: String, f: Void->Void): BenchmarkResults {
        // first determine how long it takes to acquire a sample
        var iterationsPerSample: Int = 0;

        // first test the degenerate case where the execution time is too small
        // to measure
        if(verbose) println('[Bencher]($name): calculating sample iterations');
        var startTime: Float = stamp();
        f();
        var endTime: Float = stamp();

        if(endTime - startTime == 0.0) {
            // we can't measure the execution because the system isn't accurate
            // enough, so do the somewhat innacurate way of repeating a ton of times
            if(verbose) println('[Bencher]($name): warning: degenerate case, your function is too fast!');
            startTime = stamp();
            do {
                f();
                endTime = stamp();
                iterationsPerSample++;
            } while(endTime - startTime < minSecondsPerSample);
        }
        else {
            // we can measure individual runs, so do that
            // we already took a sample, so use that to start with
            var runningTimer: Float = endTime - startTime;
            iterationsPerSample++;
            while(runningTimer < minSecondsPerSample) {
                startTime = stamp();
                f();
                endTime = stamp();
                runningTimer += endTime - startTime;
                iterationsPerSample++;
            }
        }
        if(verbose) println('[Bencher]($name): ${iterationsPerSample} iterations required to take ${minSecondsPerSample} sample');

        // ok, now we know how many times we need to run in order to get a sample,
        // collect our samples!
        if(verbose) println('[Bencher]($name): ${iterationsPerSample} running benchmark...');
        var samples: Array<Float> = [];
        var printMod: Int = Std.int(samplesPerBenchmark / 10);
        for(i in 0...this.samplesPerBenchmark) {
            var startTime: Float = stamp();
            for(_ in 0...iterationsPerSample) f();
            var endTime: Float = stamp();
            samples.push((endTime - startTime) / iterationsPerSample);
            if(i % printMod == 0 && verbose) print('\r[Bencher]($name): ${Math.round((i + 1) / samplesPerBenchmark * 100)}%');
        }
        if(verbose) println('\n[Bencher]($name): Completed!');
        
        // and store the result
        var results = new BenchmarkResults(samples);
        this.benchmarks.set(name, results);
        return results;
    }

    function formatReport(benches: Array<{name: String, results: BenchmarkResults}>): String {
        var columnAWidth: Int = 0;
        var columnBWidth: Int = 0;
        for(bench in benches) {
            if(bench.name.length > columnAWidth) columnAWidth = bench.name.length;
            if(bench.results.toString().length > columnBWidth) columnBWidth = bench.results.toString().length;
        }
        var s: String = "";
        s += '| ${"Benchmark".rpad(" ", columnAWidth)} | ${"Mean Time / Iteration".rpad(" ", columnBWidth)} |\n';
        s += '|:${"".rpad("-", columnAWidth)}-|:${"".rpad("-", columnBWidth)}-|\n';
        for(bench in benches) {
            s += '| ${bench.name.rpad(" ", columnAWidth)} | ${bench.results.toString().rpad(" ", columnBWidth)} |\n';
        }
        return s;
    }

    function formatReportWithChanges(benches: Array<{name: String, results: BenchmarkResults}>, old: StringMap<BenchmarkResults>, differences: StringMap<String>): String {
        var columnAWidth: Int = "Benchmark".length;
        var columnBWidth: Int = "New Mean Time / Iteration".length;
        var columnCWidth: Int = "Old Mean Time / Iteration".length;
        var columnDWidth: Int = "Difference".length;
        for(bench in benches) {
        if(bench.name.length > columnAWidth) columnAWidth = bench.name.length;
        if(bench.results.toString().length > columnBWidth) columnBWidth = bench.results.toString().length;
        }
        for(o in old.iterator()) {
        if(o.toString().length > columnCWidth) columnCWidth = o.toString().length;
        }
        for(diff in differences.iterator()) {
        if(diff.length > columnDWidth) columnDWidth = diff.length;
        }
        var s: String = "";
        s += '| ${"Benchmark".rpad(" ", columnAWidth)} | ${"New Mean Time / Iteration".rpad(" ", columnBWidth)} | ${"Old Mean Time / Iteration".rpad(" ", columnCWidth)} | ${"Difference".rpad(" ", columnDWidth)} |\n';
        s += '|:${"".rpad("-", columnAWidth)}-|:${"".rpad("-", columnBWidth)}-|:${"".rpad("-", columnCWidth)}-|:${"".rpad("-", columnDWidth)}-|\n';
        for(bench in benches) {
        s += '| ${bench.name.rpad(" ", columnAWidth)} | ${bench.results.toString().rpad(" ", columnBWidth)} | ${old.get(bench.name).toString().rpad(" ", columnCWidth)} | ${differences.get(bench.name).rpad(" ", columnDWidth)} |\n';
        }
        return s;
    }

    /**
    Generate a [Markdown table](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet) of all the benchmarked results
    @return String
    **/
    public function generateReport(): String {
        var benches: Array<{name: String, results: BenchmarkResults}> = [for(kv in benchmarks.keyValueIterator()) {name: kv.key, results: kv.value}];
        ArraySort.sort(benches, (a, b) -> Reflect.compare(a.name, b.name));
        return formatReport(benches);
    }

    /**
    If you change your code and generate a new benchmark, use this to compare the changes to see if the changes had
    a statistically significant effect. Generally this is done by serializing a `Benched` instance, changing the code,
    re-running benchmarks, and then deserializing the old benchmarks, and supplying them to this function
    @param old The previous run of the same benchmarks, with possibly different implementations
    @return String
    **/
    public function generateComparisonReport(old: Benched): String {
        var benches: Array<{name: String, results: BenchmarkResults}> = [for(kv in benchmarks.keyValueIterator()) {name: kv.key, results: kv.value}];
        ArraySort.sort(benches, (a, b) -> Reflect.compare(a.name, b.name));
        var differences: StringMap<String> = new StringMap();
        
        for(bench in benches) {
        if(old.benchmarks.exists(bench.name)) {
            var different: Bool = bench.results.isMeanDifferent(old.benchmarks.get(bench.name));
            differences.set(bench.name, switch([different, bench.results.mean < old.benchmarks.get(bench.name).mean]) {
                case [true, true]: "Faster!";
                case [true, false]: "Slower!";
                case [false, _]: "No Change";
            });
        }
        else {
            differences.set(bench.name, "—");
        }
    }

    return formatReportWithChanges(benches, old.benchmarks, differences);
    }
 }
 