/**
 * ROD CUTTING PROBLEM -- DYNAMIC PROGRAMMING
 *
 * Problem: given a rod of length n and a price table price[i] giving the
 * price of a piece of length i (1 <= i <= n), determine the maximum
 * total revenue obtainable by cutting the rod into pieces of integer
 * lengths and selling them (cutting is free, and you may also choose not
 * to cut at all).
 *
 * Core idea (recurrence relation): let dp[len] be the maximum revenue
 * obtainable from a rod of length len. To form a rod of length len, think
 * of the FIRST cut: it produces one piece of some length cut (1 <= cut <=
 * len), sold for price[cut], leaving a remaining rod of length
 * (len - cut) to be optimally cut on its own (that's dp[len - cut]).
 * We try every possible first-cut length and keep the best:
 *   dp[len] = max over all cut in [1, len] of ( price[cut] + dp[len - cut] )
 * Base case: dp[0] = 0 (a rod of length 0 yields no revenue).
 * This is really unbounded knapsack in disguise: each "item" is a rod
 * piece of a given length/price, reusable any number of times, and we
 * want to exactly fill a rod of length n to maximize value.
 *
 * Time complexity: O(n^2) -- for each rod length from 1 to n we try every
 * possible first cut.
 * Space complexity: O(n) for the dp array.
 */
public class RodCutting {

    // price[i-1] is the price of a piece of length i
    public static int maxRevenue(int[] price, int n) {
        int[] dp = new int[n + 1];
        for (int len = 1; len <= n; len++) {
            int best = Integer.MIN_VALUE;
            for (int cut = 1; cut <= len; cut++) {
                int candidate = price[cut - 1] + dp[len - cut];
                if (candidate > best) {
                    best = candidate;
                }
            }
            dp[len] = best;
        }
        return dp[n];
    }

    public static void main(String[] args) {
        // price[i-1] = price of a piece of length i, for i = 1..8
        int[] price = {1, 5, 8, 9, 10, 17, 17, 20};
        int rodLength = 8;

        System.out.println("Rod Cutting Problem");
        System.out.println("Rod length: " + rodLength);
        for (int i = 0; i < price.length; i++) {
            System.out.println("Price of piece of length " + (i + 1) + ": " + price[i]);
        }

        int result = maxRevenue(price, rodLength);
        System.out.println();
        System.out.println("Final computed answer -> Maximum obtainable revenue: " + result);
    }
}
