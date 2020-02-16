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
        bencher.benchmark("Fibonacci(20)", () -> fibonacci(20));
        bencher.benchmark("Fibonacci(100)", () -> fibonacci(100));
        Sys.println('### Naive Implementation');
        Sys.println(bencher.generateReport());
        Sys.println(bencher.generateComparisonReport(oldBencher));

        // save the results for later
        var s = new Serializer();
        s.serialize(bencher);
        sys.io.File.saveContent("_fib.hxs", s.toString());
    }
}
```

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
        bencher.benchmark("Fibonacci(20)", () -> fibonacci_naive(20));
        bencher.benchmark("Fibonacci(100)", () -> fibonacci_naive(100));
        Sys.println('### Optimized Implementation');
        Sys.println(bencher.generateReport());

        // now load our old results and see if we made things faster
        var oldBencher: Benched = new Unserializer(sys.io.File.getContent("_fib_naive.hxs")).unserialize();
        Sys.println("### Changes");
        Sys.println(bencher.generateComparisonReport(oldBencher));
    }
}
```

### Sample Results

#### Naive Implementation
| Benchmark     | Mean Time / Iteration      |
|:--------------|:---------------------------|
| Fibonacci(1)  | 7.539 [ns] ± 1.901 [ns]    |
| Fibonacci(10) | 654.097 [ns] ± 3.377 [ns]  |
| Fibonacci(20) | 80.419 [μs] ± 499.973 [ns] |

#### Optimized Implementation
| Benchmark     | Mean Time / Iteration    |
|:--------------|:-------------------------|
| Fibonacci(1)  | 14.370 [ns] ± 1.266 [ns] |
| Fibonacci(10) | 23.526 [ns] ± 1.961 [ns] |
| Fibonacci(20) | 42.985 [ns] ± 1.793 [ns] |

#### Changes
| Benchmark     | New Mean Time / Iteration | Old Mean Time / Iteration  | Difference |
|:--------------|:--------------------------|:---------------------------|:-----------|
| Fibonacci(1)  | 14.370 [ns] ± 1.266 [ns]  | 7.539 [ns] ± 1.901 [ns]    | Slower!    |
| Fibonacci(10) | 23.526 [ns] ± 1.961 [ns]  | 654.097 [ns] ± 3.377 [ns]  | Faster!    |
| Fibonacci(20) | 42.985 [ns] ± 1.793 [ns]  | 80.419 [μs] ± 499.973 [ns] | Faster!    |