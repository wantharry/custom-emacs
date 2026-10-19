/**
 * GREATEST COMMON DIVISOR (GCD) via the Euclidean Algorithm
 *
 * What it does:
 *   Computes the largest positive integer that divides two given
 *   integers without leaving a remainder.
 *
 * Core idea / how it works:
 *   Based on the fact that gcd(a, b) == gcd(b, a mod b). Repeatedly
 *   replace the pair (a, b) with (b, a mod b) until b becomes 0 -- at
 *   that point a is the GCD. Intuitively: any common divisor of a and b
 *   must also divide a - b (and more generally a mod b), so shrinking the
 *   pair this way never loses the common divisor, and it shrinks fast
 *   because each remainder is strictly smaller than the previous divisor.
 *
 * Time complexity:  O(log(min(a, b)))  -- the pair shrinks roughly like
 *                    the Fibonacci sequence in reverse; this is one of
 *                    the fastest classic number-theory algorithms.
 * Space complexity: O(1) iterative (or O(log(min(a,b))) recursion stack
 *                    if written recursively).
 */
public class GCD {

    public static long gcd(long a, long b) {
        a = Math.abs(a);
        b = Math.abs(b);
        while (b != 0) {
            long temp = b;
            b = a % b;
            a = temp;
        }
        return a;
    }

    public static void main(String[] args) {
        long[][] pairs = {{48, 18}, {101, 103}, {1071, 462}, {0, 5}, {17, 17}};
        System.out.println("Computing GCD for several pairs:");
        for (long[] pair : pairs) {
            System.out.println("  gcd(" + pair[0] + ", " + pair[1] + ") = " + gcd(pair[0], pair[1]));
        }
    }
}
