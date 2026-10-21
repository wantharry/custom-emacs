/**
 * SUBSET SUM PROBLEM -- DYNAMIC PROGRAMMING
 *
 * Problem: given a set (array) of non-negative integers and a target
 * sum, determine whether any subset of the array sums to exactly that
 * target.
 *
 * Core idea (recurrence relation): let dp[i][s] be true if some subset
 * of the first i elements sums to exactly s. For element i (1-indexed,
 * value arr[i-1]) we have two choices:
 *   - Don't include it:  dp[i][s] = dp[i-1][s]
 *   - Include it (only if arr[i-1] <= s): dp[i][s] = dp[i-1][s - arr[i-1]]
 * dp[i][s] is true if EITHER option is true:
 *   dp[i][s] = dp[i-1][s] OR (arr[i-1] <= s AND dp[i-1][s - arr[i-1]])
 * Base case: dp[i][0] = true for all i (the empty subset always sums to
 * 0), and dp[0][s] = false for s > 0 (no elements can't reach a positive
 * target).
 * This is the boolean analogue of 0/1 knapsack: instead of maximizing
 * value, we only need to know reachability, which simplifies "take or
 * skip" into "true or false" rather than "max of two values".
 *
 * Space can be reduced to a 1D boolean array of size (target+1), iterated
 * for each element with the sum dimension processed in DECREASING order
 * (to avoid reusing the same element twice within one pass, exactly like
 * 0/1 knapsack's space optimization).
 *
 * Time complexity: O(n * target).
 * Space complexity: O(target) using the 1D rolling-array optimization
 * shown here.
 */
public class SubsetSum {

    public static boolean hasSubsetWithSum(int[] arr, int target) {
        boolean[] dp = new boolean[target + 1];
        dp[0] = true; // empty subset sums to 0

        for (int value : arr) {
            for (int s = target; s >= value; s--) {
                if (dp[s - value]) {
                    dp[s] = true;
                }
            }
        }
        return dp[target];
    }

    public static void main(String[] args) {
        int[] arr = {3, 34, 4, 12, 5, 2};
        int target = 9;

        System.out.println("Subset Sum Problem");
        System.out.print("Array: ");
        for (int v : arr) {
            System.out.print(v + " ");
        }
        System.out.println();
        System.out.println("Target sum: " + target);

        boolean result = hasSubsetWithSum(arr, target);
        System.out.println();
        System.out.println("Final computed answer -> Subset with target sum exists: " + result);

        int unreachableTarget = 10000;
        System.out.println("Sanity check for an unreachable target (" + unreachableTarget + "): "
                + hasSubsetWithSum(arr, unreachableTarget));
    }
}
