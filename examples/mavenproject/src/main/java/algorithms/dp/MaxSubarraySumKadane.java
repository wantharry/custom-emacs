/**
 * MAXIMUM SUBARRAY SUM -- KADANE'S ALGORITHM (DYNAMIC PROGRAMMING)
 *
 * Problem: given an array of integers (possibly containing negatives),
 * find the maximum possible sum of a CONTIGUOUS subarray (at least one
 * element).
 *
 * Core idea (recurrence relation): let dp[i] be the maximum sum of a
 * contiguous subarray that ENDS exactly at index i. Either that best
 * subarray is just the single element arr[i] on its own, or it extends
 * the best subarray ending at i-1 by appending arr[i]:
 *   dp[i] = max( arr[i], dp[i-1] + arr[i] )
 * Base case: dp[0] = arr[0].
 * The reasoning: if dp[i-1] is negative, extending it would only hurt,
 * so it's better to start fresh at arr[i]; if dp[i-1] is non-negative,
 * extending it can only help or stay the same. The overall answer is
 * max(dp[0..n-1]), since the best subarray overall must end somewhere.
 *
 * Kadane's algorithm is this exact recurrence implemented with a single
 * rolling variable (currentSum) instead of a full array, since dp[i]
 * only ever depends on dp[i-1]. We track the best currentSum seen so far
 * as bestSum, updating it whenever currentSum improves on it.
 *
 * Time complexity: O(n) -- a single pass over the array.
 * Space complexity: O(1) -- only a couple of rolling variables are kept.
 */
public class MaxSubarraySumKadane {

    public static int maxSubarraySum(int[] arr) {
        if (arr.length == 0) {
            throw new IllegalArgumentException("array must not be empty");
        }
        int currentSum = arr[0];
        int bestSum = arr[0];

        for (int i = 1; i < arr.length; i++) {
            currentSum = Math.max(arr[i], currentSum + arr[i]);
            bestSum = Math.max(bestSum, currentSum);
        }
        return bestSum;
    }

    public static void main(String[] args) {
        int[] arr = {-2, 1, -3, 4, -1, 2, 1, -5, 4};

        System.out.println("Maximum Subarray Sum (Kadane's Algorithm)");
        System.out.print("Array: ");
        for (int v : arr) {
            System.out.print(v + " ");
        }
        System.out.println();

        int result = maxSubarraySum(arr);
        System.out.println();
        System.out.println("Final computed answer -> Maximum subarray sum: " + result);
    }
}
