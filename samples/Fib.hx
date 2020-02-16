import haxe.Unserializer;
import haxe.Serializer;
import benched.Benched;

class Fib {
    static function fibonacci_naive(n: Int): Int {
        return switch n {
            case 0: 1;
            case 1: 1;
            case n: fibonacci_naive(n - 1) + fibonacci_naive(n - 2);
        }
    }

    static function fibonacci_optimized(n: Int): Int {
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
        // first run our naive benchmark and serialize it
        // let's pretend we ran this before writing `fibonacci_optimized`
        var bencher = new Benched();
        bencher.benchmark("Fibonacci(1)", () -> fibonacci_naive(1));
        bencher.benchmark("Fibonacci(10)", () -> fibonacci_naive(10));
        bencher.benchmark("Fibonacci(20)", () -> fibonacci_naive(20));
        var s = new Serializer();
        s.serialize(bencher);
        sys.io.File.saveContent("_fib_naive.hxs", s.toString());
        Sys.println('### Naive Implementation');
        Sys.println(bencher.generateReport());

        // ... some time passes ...

        // now we've made some changes to our fibonacci calculator (`fibonacci_optimized`)
        // benchmark the results
        var bencher = new Benched();
        bencher.benchmark("Fibonacci(1)", () -> fibonacci_optimized(1));
        bencher.benchmark("Fibonacci(10)", () -> fibonacci_optimized(10));
        bencher.benchmark("Fibonacci(20)", () -> fibonacci_optimized(20));
        Sys.println('### Optimized Implementation');
        Sys.println(bencher.generateReport());

        // now load our old results and see if we made things faster
        var oldBencher: Benched = new Unserializer(sys.io.File.getContent("_fib_naive.hxs")).unserialize();
        Sys.println("### Changes");
        Sys.println(bencher.generateComparisonReport(oldBencher));
    }
}