/**
 * PERFECT NUMBER CHECK
 *
 * What it does:
 *   Determines whether a positive integer is a "perfect number" -- a
 *   number that equals the sum of all of its proper divisors (divisors
 *   excluding the number itself). Example: 28's proper divisors are
 *   1, 2, 4, 7, 14, and 1+2+4+7+14 = 28.
 *
 * Core idea / how it works:
 *   Find all divisors of n by scanning i from 1 up to sqrt(n). Whenever i
 *   divides n evenly, both i and n/i are divisors (unless they're equal,
 *   e.g. for perfect squares, in which case count it only once). Sum all
 *   divisors found this way except n itself, then compare the sum to n.
 *   Scanning only up to sqrt(n) and picking up the paired divisor n/i
 *   avoids the slower approach of checking every number from 1 to n-1.
 *
 * Time complexity:  O(sqrt(n)).
 * Space complexity: O(1).
 */
public class PerfectNumberCheck {

    public static boolean isPerfect(long n) {
        if (n <= 1) return false;
        long sumOfDivisors = 1; // 1 is always a proper divisor (for n > 1)

        for (long i = 2; i * i <= n; i++) {
            if (n % i == 0) {
                sumOfDivisors += i;
                long paired = n / i;
                if (paired != i) {
                    sumOfDivisors += paired;
                }
            }
        }
        return sumOfDivisors == n;
    }

    public static void main(String[] args) {
        long[] candidates = {6, 28, 12, 496, 100, 8128, 33550336};
        System.out.println("Perfect number check:");
        for (long n : candidates) {
            System.out.println("  " + n + " is perfect? " + isPerfect(n));
        }
    }
}
