/**
 * PRIMALITY TEST (Trial Division up to sqrt(n))
 *
 * What it does:
 *   Determines whether a single given number n is prime (has no
 *   positive divisors other than 1 and itself).
 *
 * Core idea / how it works:
 *   A number n is composite if and only if it has a divisor d with
 *   1 < d <= sqrt(n) -- because if n = d1 * d2 with both factors greater
 *   than sqrt(n), their product would exceed n, a contradiction. So it's
 *   enough to test divisibility by every integer from 2 up to sqrt(n).
 *   As a small optimization, after handling 2 and 3 directly, every
 *   remaining candidate divisor can be checked in steps of 6 (only
 *   numbers of the form 6k+-1 can be prime beyond 3), roughly tripling
 *   the speed over a plain 2..sqrt(n) loop.
 *
 * Time complexity:  O(sqrt(n))  -- per number tested.
 * Space complexity: O(1).
 */
public class IsPrime {

    public static boolean isPrime(long n) {
        if (n < 2) return false;
        if (n == 2 || n == 3) return true;
        if (n % 2 == 0 || n % 3 == 0) return false;

        for (long i = 5; i * i <= n; i += 6) {
            if (n % i == 0 || n % (i + 2) == 0) return false;
        }
        return true;
    }

    public static void main(String[] args) {
        long[] candidates = {1, 2, 3, 4, 17, 18, 97, 100, 7919, 7920, 1000000007};
        System.out.println("Primality check:");
        for (long n : candidates) {
            System.out.println("  " + n + " is prime? " + isPrime(n));
        }
    }
}
