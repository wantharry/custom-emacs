/**
 * FIBONACCI SEQUENCE VIA DYNAMIC PROGRAMMING (BOTTOM-UP TABULATION)
 *
 * Problem: compute the n-th Fibonacci number, defined by F(0)=0, F(1)=1,
 * and F(n) = F(n-1) + F(n-2) for n >= 2.
 *
 * Core idea: the naive recursive solution recomputes the same sub-values
 * exponentially many times (F(5) calls F(4) and F(3), F(4) calls F(3) and
 * F(2), etc. -- F(3) gets recomputed over and over). Dynamic programming
 * fixes this by solving each distinct sub-problem exactly once and storing
 * ("memoizing") the result so it can be reused.
 *
 * Here we use bottom-up tabulation: we build an array dp[] where dp[i]
 * holds F(i), starting from the known base cases dp[0]=0 and dp[1]=1 and
 * filling upward using the recurrence dp[i] = dp[i-1] + dp[i-2]. By the
 * time we need dp[i], dp[i-1] and dp[i-2] are already known, so no
 * recomputation ever happens.
 *
 * We also show the O(1)-space variant, which only needs the last two
 * values at any time instead of the whole table.
 *
 * Time complexity: O(n) -- each of the n sub-problems is solved once in
 * constant time.
 * Space complexity: O(n) for the tabulated array version, or O(1) for the
 * rolling-variable version.
 */
public class FibonacciDP {

    // Bottom-up tabulation using a full array (easier to reason about,
    // and generalizes well to problems where you need to inspect earlier
    // entries, not just the immediately preceding two).
    public static long fibTable(int n) {
        if (n < 0) {
            throw new IllegalArgumentException("n must be non-negative");
        }
        long[] dp = new long[n + 1 < 2 ? 2 : n + 1];
        dp[0] = 0;
        if (n >= 1) {
            dp[1] = 1;
        }
        for (int i = 2; i <= n; i++) {
            dp[i] = dp[i - 1] + dp[i - 2];
        }
        return dp[n];
    }

    // Space-optimized version: only the last two Fibonacci numbers are
    // ever needed, so we can drop the array entirely.
    public static long fibRolling(int n) {
        if (n < 0) {
            throw new IllegalArgumentException("n must be non-negative");
        }
        if (n == 0) {
            return 0;
        }
        long prev2 = 0; // F(i-2)
        long prev1 = 1; // F(i-1)
        for (int i = 2; i <= n; i++) {
            long current = prev1 + prev2;
            prev2 = prev1;
            prev1 = current;
        }
        return prev1;
    }

    public static void main(String[] args) {
        System.out.println("Fibonacci via bottom-up DP (tabulation and rolling variables)");
        System.out.println("---------------------------------------------------------------");
        for (int n = 0; n <= 15; n++) {
            System.out.println("F(" + n + ") = " + fibTable(n) + " (table), " + fibRolling(n) + " (rolling)");
        }

        int target = 40;
        long result = fibRolling(target);
        System.out.println();
        System.out.println("Final computed answer -> F(" + target + ") = " + result);
    }
}
