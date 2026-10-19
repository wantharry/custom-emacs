/**
 * LONGEST INCREASING SUBSEQUENCE (LIS) -- DYNAMIC PROGRAMMING
 *
 * Problem: given an array of numbers, find the length of the longest
 * strictly increasing subsequence (elements need not be contiguous, but
 * must appear in the same relative order as in the original array, and
 * each must be strictly greater than the previous one).
 *
 * Core idea (recurrence relation), O(n^2) approach: let dp[i] be the
 * length of the longest increasing subsequence that ENDS exactly at index
 * i. To compute dp[i], look at every earlier index j < i: if
 * arr[j] < arr[i], then the subsequence ending at j can be extended by
 * arr[i], giving a candidate length dp[j] + 1. We take the best such
 * candidate over all valid j:
 *   dp[i] = 1 + max( dp[j] for all j < i where arr[j] < arr[i] ),
 *           or dp[i] = 1 if no such j exists (the element starts its own
 *           subsequence of length 1).
 * The overall answer is max(dp[0..n-1]).
 *
 * This works because any increasing subsequence ending at i must have
 * been an increasing subsequence ending at some earlier, smaller element
 * j, immediately before appending arr[i] -- so the best subsequence
 * ending at i is built from the best subsequence ending at the best
 * qualifying predecessor.
 *
 * (A faster O(n log n) approach exists using binary search over a
 * "tails" array, but the O(n^2) table-based version shown here is the
 * clearest illustration of the DP recurrence.)
 *
 * Time complexity: O(n^2) -- for each i we scan all earlier j.
 * Space complexity: O(n) for the dp array.
 */
public class LongestIncreasingSubsequence {

    public static int lengthOfLIS(int[] arr) {
        int n = arr.length;
        if (n == 0) {
            return 0;
        }
        int[] dp = new int[n];
        for (int i = 0; i < n; i++) {
            dp[i] = 1; // every element is an increasing subsequence of length 1 by itself
            for (int j = 0; j < i; j++) {
                if (arr[j] < arr[i] && dp[j] + 1 > dp[i]) {
                    dp[i] = dp[j] + 1;
                }
            }
        }
        int best = 0;
        for (int value : dp) {
            if (value > best) {
                best = value;
            }
        }
        return best;
    }

    public static void main(String[] args) {
        int[] arr = {10, 9, 2, 5, 3, 7, 101, 18};

        System.out.println("Longest Increasing Subsequence");
        System.out.print("Array: ");
        for (int v : arr) {
            System.out.print(v + " ");
        }
        System.out.println();

        int result = lengthOfLIS(arr);
        System.out.println();
        System.out.println("Final computed answer -> LIS length: " + result);
    }
}
