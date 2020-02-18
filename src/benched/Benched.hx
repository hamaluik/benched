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
using Lambda;
using StringTools;

private enum TableAlignment {
    Left;
    Center;
    Right;
}

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
     All our benchmarks (an `Array` instead of `haxe.ds.StringMap` in order to preserve order)
    **/
    var benchmarks: Array<{name: String, results: BenchmarkResults}>;

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
        this.benchmarks = [];
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
        if(verbose) println('[Benched]($name): calculating sample iterations');
        var startTime: Float = stamp();
        f();
        var endTime: Float = stamp();

        if(endTime - startTime == 0.0) {
            // we can't measure the execution because the system isn't accurate
            // enough, so do the somewhat innacurate way of repeating a ton of times
            if(verbose) println('[Benched]($name): warning: degenerate case, your function is too fast!');
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
        if(verbose) println('[Benched]($name): ${iterationsPerSample} iterations required to take ${minSecondsPerSample} sample');

        // ok, now we know how many times we need to run in order to get a sample,
        // collect our samples!
        if(verbose) println('[Benched]($name): ${iterationsPerSample} running benchmark...');
        var samples: Array<Float> = [];
        var printMod: Int = Std.int(samplesPerBenchmark / 10);
        for(i in 0...this.samplesPerBenchmark) {
            var startTime: Float = stamp();
            for(_ in 0...iterationsPerSample) f();
            var endTime: Float = stamp();
            samples.push((endTime - startTime) / iterationsPerSample);
            if(i % printMod == 0 && verbose) print('\r[Benched]($name): ${Math.round((i + 1) / samplesPerBenchmark * 100)}%');
        }
        if(verbose) println('\n[Benched]($name): Completed!');

        // and store the result
        var results = new BenchmarkResults(samples);
        this.benchmarks.push({name: name, results: results});
        return results;
    }

    static function formatTable(headers: Array<String>, alignments: Array<TableAlignment>, rows: Array<Array<String>>): String {
        final widths: Array<Int> = headers.mapi(function(column: Int, header: String): Int {
            function max(a: Int, b: Int): Int {
                return a > b ? a : b;
            }
            return rows.map((r) -> r[column].length).fold(max, header.length);
        });

        var table: String = "";

        // first the headers
        for(i in 0...headers.length) {
            table += switch(alignments[i]) {
                case Left, Center: '| ${headers[i].rpad(" ", widths[i])} ';
                case Right:        '| ${headers[i].lpad(" ", widths[i])} ';
            };
        }
        table += "|\n";

        // now alignments
        for(i in 0...alignments.length) {
            var leftChar: String = switch(alignments[i]) {
                case Left, Center: ":";
                case Right: "-";
            };
            var rightChar: String = switch(alignments[i]) {
                case Left: "-";
                case Right, Center: ":";
            };
            table += "|" + leftChar + StringTools.rpad("", "-", widths[i]) + rightChar;
        }
        table += "|\n";

        // now the rows
        for(row in rows) {
            for(i in 0...row.length) {
                table += switch(alignments[i]) {
                    case Left, Center: '| ${row[i].rpad(" ", widths[i])} ';
                    case Right:        '| ${row[i].lpad(" ", widths[i])} ';
                };
            }
            table += "|\n";
        }

        return table;
    }

    /**
    Generate a [Markdown table](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet) of all the benchmarked results
    @return String
    **/
    public function generateReport(): String {
        final benches: Array<Array<String>> = this.benchmarks.map((b) -> [
            b.name,
            '`${b.results.toString()}`',
        ]);
        return formatTable(
            ["Benchmark", "Mean Time / Iteration"],
            [Left, Right],
            benches
        );
    }

    /**
    If you change your code and generate a new benchmark, use this to compare the changes to see if the changes had
    a statistically significant effect. Generally this is done by serializing a `Benched` instance, changing the code,
    re-running benchmarks, and then deserializing the old benchmarks, and supplying them to this function. This generates
    a [Markdown table](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet) similar to `generateReport()`
    but with more columns of details.
    @param old The previous run of the same benchmarks, with possibly different implementations
    @return String
    **/
    public function generateComparisonReport(old: Benched): String {
        // first get a list of our benchmarks
        final benches: Array<{
            name: String,
            results: BenchmarkResults,
            oldResults: Null<BenchmarkResults>,
        }> = [for(bench in this.benchmarks) {
            name: bench.name,
            results: bench.results,
            oldResults: {
                var oldResults = old.benchmarks.find((b) -> b.name == bench.name);
                if(oldResults == null) null;
                else oldResults.results;
            }
        }];

        // now format them
        final benches: Array<Array<String>> = benches.map((b) -> [
            b.name,
            '`${b.results.toString()}`',
            b.oldResults == null ? '—' : '`${b.oldResults.toString()}`',
            if(b.oldResults != null) {
                switch([b.results.mean < b.oldResults.mean, b.results.isMeanDifferent(b.oldResults)]) {
                    case [true, true]: '~${BenchmarkResults.floatToStringPrecision(b.oldResults.mean / b.results.mean, 1)}× _Faster_';
                    case [false, true]: '~${BenchmarkResults.floatToStringPrecision(b.results.mean / b.oldResults.mean, 1)}× **Slower**';
                    case [_, false]: "No Change";
                }
            }
            else {
                "—";
            },
            if(b.oldResults != null) {
                var change = b.results.percentDifference(b.oldResults);
                (change >= 0 ? "+" : "") + BenchmarkResults.floatToStringPrecision(change, 1) + "%";
            }
            else {
                "—";
            }
        ]);
        return formatTable(
            ["Benchmark", "Mean Time / Iteration", "Old Mean Time / Iteration", "Change", "Performance Difference"],
            [Left, Right, Right, Left, Right],
            benches
        );
    }
 }
