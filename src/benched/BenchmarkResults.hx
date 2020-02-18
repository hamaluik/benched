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

using Lambda;

/**
 A collection of values representing a timing sample
**/
@:forward
@:allow(benched.Benched)
abstract BenchmarkResults(Array<Float>) {
    /**
     The mean of the sample
    **/
    public var mean(get, never): Float;

    /**
     The standard distribution of the sample
    **/
    public var std(get, never): Float;

    /**
     The variance of the sample
    **/
    public var variance(get, never): Float;

    /**
     Create a new result, which is a list of timings in seconds
     @param results
    **/
    function new(results: Array<Float>) {
        this = results;
    }

    /**
     Calculate whether the means of the two results are statistically different
     with `α = 0.05` (`p = 0.95`). Returns `true` if the means are statistically
     different
     @param other the other result to compare against.
     @return Bool
    **/
    public function isMeanDifferent(other: BenchmarkResults): Bool {
        // calculate t-statistic
        var df: Int = this.length + other.length - 2;
        var sw: Float = Math.sqrt(((this.length - 1) * variance + (other.length - 1) * other.variance) / df);
        var se: Float = sw * Math.sqrt((1 / this.length) + (1 / other.length));
        var t: Float = Math.abs(mean - other.mean) / se;

        // 2-tailed with alpha = 0.05
        var table: Array<Float> = [Math.NaN, 12.7065, 4.3026, 3.1824, 2.7764, 2.5706, 2.4469, 2.3646, 2.3060, 2.2621, 2.2282, 2.2010, 2.1788, 2.1604, 2.1448, 2.1314, 2.1199, 2.1098, 2.1009, 2.0930, 2.0860, 2.0796, 2.0739, 2.0686, 2.0639, 2.0596, 2.0555, 2.0518, 2.0484, 2.0452, 2.0423, 2.0395, 2.0369, 2.0345, 2.0322, 2.0301, 2.0281, 2.0262, 2.0244, 2.0227, 2.0211, 2.0196, 2.0181, 2.0167, 2.0154, 2.0141, 2.0129, 2.0117, 2.0106, 2.0096, 2.0086, 2.0076, 2.0066, 2.0057, 2.0049, 2.0041, 2.0032, 2.0025, 2.0017, 2.0010, 2.0003, 1.9996, 1.9990, 1.9983, 1.9977, 1.9971, 1.9966, 1.9960, 1.9955, 1.9950, 1.9944, 1.9939, 1.9935, 1.9930, 1.9925, 1.9921, 1.9917, 1.9913, 1.9909, 1.9904, 1.9901, 1.9897, 1.9893, 1.9889, 1.9886, 1.9883, 1.9879, 1.9876, 1.9873, 1.9870, 1.9867, 1.9864, 1.9861, 1.9858, 1.9855, 1.9852, 1.9850, 1.9847, 1.9845, 1.9842, 1.9840, 1.9837, 1.9835, 1.9833, 1.9830, 1.9828, 1.9826, 1.9824, 1.9822, 1.9820, 1.9818, 1.9816, 1.9814, 1.9812, 1.9810, 1.9808, 1.9806, 1.9805, 1.9803, 1.9801, 1.9799, 1.9798, 1.9796, 1.9794, 1.9793, 1.9791, 1.9790, 1.9788, 1.9787, 1.9785, 1.9784, 1.9782, 1.9781, 1.9779, 1.9778, 1.9777, 1.9776, 1.9774, 1.9773, 1.9772, 1.9771, 1.9769, 1.9768, 1.9767, 1.9766, 1.9765, 1.9764, 1.9762, 1.9761, 1.9760, 1.9759, 1.9758, 1.9757, 1.9756, 1.9755, 1.9754, 1.9753, 1.9752, 1.9751, 1.9750, 1.9749, 1.9748, 1.9747, 1.9746, 1.9745, 1.9744, 1.9744, 1.9743, 1.9742, 1.9741, 1.9740, 1.9739, 1.9739, 1.9738, 1.9737, 1.9736, 1.9735, 1.9735, 1.9734, 1.9733, 1.9732, 1.9731, 1.9731, 1.9730, 1.9729, 1.9729, 1.9728, 1.9727, 1.9727, 1.9726, 1.9725, 1.9725, 1.9724, 1.9723, 1.9723, 1.9722, 1.9721, 1.9721, 1.9720, 1.9720, 1.9719];
        // TODO: higher DoF?
        if(df > 200) df = 200;
        var t_table: Float = table[df];
        return t >= t_table;
    }

    /**
     Calculate the % difference (0―100) between this benchmark and the other,
     using the other as the basis for comparison
     @param other the other / old benchmark to compare against
     @return Float
     **/
    public function percentDifference(other: BenchmarkResults): Float {
        return 100.0 * (mean - other.mean) / other.mean;
    }

    function get_mean(): Float {
        var sum: Float = 0;
        for(result in this) {
            sum += result;
        }
        return sum / this.length;
    }

    function get_std(): Float {
        return Math.sqrt(variance);
    }

    function get_variance(): Float {
        var mean: Float = mean;
        var sum: Float = 0;
        for(result in this) {
            sum += (result - mean) * (result - mean);
        }
        return sum / this.length;
    }

    /**
     Utility to convert a float to a given precision with padded 0's
     @param n the number to convert
     @param prec the number of decimal places to display
     @see https://stackoverflow.com/a/23785753
     **/
    public static function floatToStringPrecision(n:Float, prec:Int){
        n = Math.round(n * Math.pow(10, prec));
        var str = ''+n;
        var len = str.length;
        if(len <= prec){
            while(len < prec){
                str = '0'+str;
                len++;
            }
            return '0.'+str;
        }
        else{
            return str.substr(0, str.length-prec) + '.'+str.substr(str.length-prec);
        }
    }

    static function log10(x: Float): Float {
        return Math.log(x) / Math.log(10);
    }

    /**
     Given a number, format it in [engineering notation](https://en.wikipedia.org/wiki/Engineering_notation)
     @param x The number to format
     @param unit The base SI units of the number ("s", "g", etc)
     @return String
     **/
    static function displayEng(x: Float, unit: String): String {
        // split into mantissa and exponent
        var exp: Float = Math.ffloor(log10(x));
        var mant: Float = x / (Math.pow(10, exp));

        // convert back to original scale
        var x: Float = mant * Math.pow(10.0, exp);

        // group exponent by factors of 1000
        var p: Int = Math.floor(log10(x));
        var p3: Int = Math.floor(p / 3);

        // get root
        var value: Float = x / Math.pow(10, 3 * p3);
        var suffixes: Array<String> = ["y", "z", "a", "f", "p", "n", "μ", "m", "", "k", "M", "G", "T", "P", "E", "Z", "Y"];
        var suffix = suffixes[p3 + 8];

        // left-pad it with non-breaking spaces so eveything lines up nicely
        var number: String = floatToStringPrecision(value, 3);
        number = StringTools.lpad(number, " ", 3 + 1 + 3);

        return '$number [$suffix$unit]';
    }

    /**
     Display the results as the mean timing with an error, both in engineering notation
     @return String
    **/
    public function toString(): String {
        return '${displayEng(mean, "s")} ± ${displayEng(std, "s")}';
    }
}