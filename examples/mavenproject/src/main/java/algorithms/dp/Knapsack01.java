/**
 * 0/1 KNAPSACK PROBLEM (DYNAMIC PROGRAMMING)
 *
 * Problem: given n items, each with a weight and a value, and a knapsack
 * with maximum weight capacity W, choose a subset of items that maximizes
 * total value without exceeding W. "0/1" means each item is either taken
 * whole or not taken at all -- no fractional items, and no repeats.
 *
 * Core idea (recurrence relation): let dp[i][w] be the best value
 * achievable using only the first i items with capacity w. For item i
 * (1-indexed, weight[i-1]/value[i-1] in the 0-indexed arrays) we have two
 * choices:
 *   - Skip item i:  dp[i][w] = dp[i-1][w]
 *   - Take item i (only possible if weight[i-1] <= w):
 *       dp[i][w] = dp[i-1][w - weight[i-1]] + value[i-1]
 * We take the better of the two options:
 *   dp[i][w] = max(dp[i-1][w], dp[i-1][w - weight[i-1]] + value[i-1])
 * Base case: dp[0][w] = 0 for all w (no items means no value).
 * The reason this works is that "take or skip item i" are the only two
 * possibilities, and whichever we pick, the remaining decision is itself
 * an optimal 0/1 knapsack sub-problem on fewer items and/or less capacity
 * -- the optimal substructure property that makes DP applicable.
 *
 * Time complexity: O(n * W) -- we fill an (n+1) x (W+1) table, one O(1)
 * decision per cell.
 * Space complexity: O(n * W) for the full table (can be reduced to O(W)
 * with a rolling 1D array, since each row only needs the previous row).
 */
public class Knapsack01 {

    public static int knapsack(int[] weights, int[] values, int capacity) {
        int n = weights.length;
        int[][] dp = new int[n + 1][capacity + 1];

        for (int i = 1; i <= n; i++) {
            int w = weights[i - 1];
            int v = values[i - 1];
            for (int cap = 0; cap <= capacity; cap++) {
                dp[i][cap] = dp[i - 1][cap]; // option 1: skip item i
                if (w <= cap) {
                    int takeValue = dp[i - 1][cap - w] + v; // option 2: take item i
                    if (takeValue > dp[i][cap]) {
                        dp[i][cap] = takeValue;
                    }
                }
            }
        }
        return dp[n][capacity];
    }

    public static void main(String[] args) {
        // Items: (weight, value)
        int[] weights = {2, 3, 4, 5};
        int[] values = {3, 4, 5, 6};
        int capacity = 5;

        System.out.println("0/1 Knapsack");
        System.out.println("Capacity: " + capacity);
        for (int i = 0; i < weights.length; i++) {
            System.out.println("Item " + i + ": weight=" + weights[i] + ", value=" + values[i]);
        }

        int best = knapsack(weights, values, capacity);
        System.out.println();
        System.out.println("Final computed answer -> Maximum value achievable: " + best);
    }
}
