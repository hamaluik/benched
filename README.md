# Benched

A statistics-based benchmarking tool for [Haxe](https://haxe.org/), inspired by [criterion](https://github.com/bheisler/criterion.rs).

## API

[API documentation is available.](https://hamaluik.github.com/benched/)

## Sample

A sample is provided in [samples/Fib.hx](samples/Fib.hx). We start by calculating
the Fibonacii sequence for any given number using recursion, and benchmark the results.
Note that by default, we will collect 50 samples which take at least 0.5s each to collect,
meaning each benchmark will take at least 25s to run. Given that we're running 3
benchmarks, each time we run this it will take about a minute and a half—be patient!.

```haxe
import haxe.Serializer;
import benched.Benched;

class Fib {
    static function fibonacci(n: Int): Int {
        return switch n {
            case 0: 1;
            case 1: 1;
            case n: fibonacci(n - 1) + fibonacci(n - 2);
        }
    }

    public static function main() {
        var bencher = new Benched();
        bencher.benchmark("Fibonacci(1)", () -> fibonacci(1));
        bencher.benchmark("Fibonacci(5)", () -> fibonacci(5));
        bencher.benchmark("Fibonacci(10)", () -> fibonacci(10));
        Sys.println('### Naive Implementation');
        Sys.println(bencher.generateReport());

        // save the results for later
        var s = new Serializer();
        s.serialize(bencher);
        sys.io.File.saveContent("_fib_naive.hxs", s.toString());
    }
}
```

This generates the following table:

### Naive Implementation
| Benchmark     |         Mean Time / Iteration |
|:--------------|------------------------------:|
| Fibonacci(1)  | `890.845 [ps] ± 106.758 [ps]` |
| Fibonacci(5)  | ` 71.964 [ns] ±   5.057 [ns]` |
| Fibonacci(10) | `838.539 [ns] ±  18.815 [ns]` |

We notice this takes a bit of time, so we re-write the fibonacci function to not
be recursive and hopefully faster:

```haxe
import haxe.Unserializer;
import haxe.Serializer;
import benched.Benched;

class Fib {
    static function fibonacci(n: Int): Int {
        var a: Int = 0;
        var b: Int = 1;

        return switch(n) {
            case 0: b;
            case _: {
                for(_ in 0...n) {
                    var c = a + b;
                    a = b;
                    b = c;
                }
                b;
            }
        }
    }

    public static function main() {
        // now we've made some changes to our fibonacci calculator
        // benchmark the results
        var bencher = new Benched();
        bencher.benchmark("Fibonacci(1)", () -> fibonacci_naive(1));
        bencher.benchmark("Fibonacci(5)", () -> fibonacci_naive(5));
        bencher.benchmark("Fibonacci(10)", () -> fibonacci_naive(10));
        Sys.println('### Optimized Implementation');
        Sys.println(bencher.generateReport());

        // now load our old results and see if we made things faster
        var oldBencher: Benched = new Unserializer(sys.io.File.getContent("_fib_naive.hxs")).unserialize();
        Sys.println("### Changes");
        Sys.println(bencher.generateComparisonReport(oldBencher));
    }
}
```

This results in the following tables, showing that we've sped things up considerably!

### Optimized Implementation
| Benchmark     |         Mean Time / Iteration |
|:--------------|------------------------------:|
| Fibonacci(1)  | `  5.697 [ns] ± 300.938 [ps]` |
| Fibonacci(5)  | `  9.700 [ns] ± 192.220 [ps]` |
| Fibonacci(10) | ` 14.575 [ns] ± 355.798 [ps]` |

### Changes
| Benchmark     |         Mean Time / Iteration |     Old Mean Time / Iteration | Change           | Performance Difference |
|:--------------|------------------------------:|------------------------------:|:-----------------|-----------------------:|
| Fibonacci(1)  | `  5.697 [ns] ± 300.938 [ps]` | `890.845 [ps] ± 106.758 [ps]` | ~6.4× **Slower** |                +539.5% |
| Fibonacci(5)  | `  9.700 [ns] ± 192.220 [ps]` | ` 71.964 [ns] ±   5.057 [ns]` | ~7.4× _Faster_   |                 -86.5% |
| Fibonacci(10) | ` 14.575 [ns] ± 355.798 [ps]` | `838.539 [ns] ±  18.815 [ns]` | ~57.5× _Faster_  |                 -98.3% |
