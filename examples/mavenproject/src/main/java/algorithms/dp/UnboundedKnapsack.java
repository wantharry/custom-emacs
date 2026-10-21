/**
 * UNBOUNDED KNAPSACK PROBLEM (DYNAMIC PROGRAMMING)
 *
 * Problem: like the 0/1 knapsack, we have items with weights and values
 * and a knapsack of capacity W, but now each item can be used an
 * UNLIMITED number of times. We want the maximum total value achievable
 * without exceeding capacity W.
 *
 * Core idea (recurrence relation): let dp[w] be the best value achievable
 * with capacity exactly w (using any items, any number of times). For
 * each capacity w, we try including one more copy of every item i whose
 * weight fits:
 *   dp[w] = max over all items i with weight[i] <= w of
 *           ( dp[w - weight[i]] + value[i] ),  or dp[w] stays 0 if none fit.
 * Because an item can be reused, dp[w - weight[i]] may itself already
 * include that same item -- that's exactly what allows unlimited reuse.
 * This is different from 0/1 knapsack, where using item i forces us to
 * look at a strictly smaller *item index* (dp[i-1][...]) to avoid reuse;
 * here we only need a single 1D array indexed by capacity, and we
 * deliberately allow revisiting the same item.
 *
 * Time complexity: O(n * W) -- for each of the W+1 capacities we scan all
 * n items.
 * Space complexity: O(W) for the 1D dp array.
 */
public class UnboundedKnapsack {

    public static int unboundedKnapsack(int[] weights, int[] values, int capacity) {
        int n = weights.length;
        int[] dp = new int[capacity + 1];

        for (int w = 1; w <= capacity; w++) {
            for (int i = 0; i < n; i++) {
                if (weights[i] <= w) {
                    int candidate = dp[w - weights[i]] + values[i];
                    if (candidate > dp[w]) {
                        dp[w] = candidate;
                    }
                }
            }
        }
        return dp[capacity];
    }

    public static void main(String[] args) {
        // Items: (weight, value) -- each can be used any number of times
        int[] weights = {1, 3, 4, 5};
        int[] values = {1, 4, 5, 7};
        int capacity = 8;

        System.out.println("Unbounded Knapsack");
        System.out.println("Capacity: " + capacity);
        for (int i = 0; i < weights.length; i++) {
            System.out.println("Item " + i + ": weight=" + weights[i] + ", value=" + values[i]);
        }

        int best = unboundedKnapsack(weights, values, capacity);
        System.out.println();
        System.out.println("Final computed answer -> Maximum value achievable: " + best);
    }
}
