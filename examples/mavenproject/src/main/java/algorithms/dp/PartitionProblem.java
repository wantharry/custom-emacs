/**
 * PARTITION PROBLEM (EQUAL SUBSET SUM PARTITION) -- DYNAMIC PROGRAMMING
 *
 * Problem: given an array of positive integers, determine whether it can
 * be partitioned into two subsets such that the sum of elements in both
 * subsets is equal.
 *
 * Core idea: let total be the sum of all elements. If total is odd, an
 * equal partition is impossible immediately (you can't split an odd
 * number into two equal integer halves). If total is even, the question
 * reduces exactly to the SUBSET SUM problem: does some subset sum to
 * total / 2? If such a subset S exists, the remaining elements
 * (everything not in S) automatically also sum to total / 2, giving the
 * required equal partition.
 *
 * Recurrence relation (identical reasoning to Subset Sum): let dp[s] be
 * true if some subset of the elements processed so far sums to exactly
 * s. For each new element v, processing sums in decreasing order:
 *   dp[s] = dp[s] OR dp[s - v]   (for s from target down to v)
 * Base case: dp[0] = true (the empty subset sums to 0).
 *
 * Time complexity: O(n * total/2).
 * Space complexity: O(total/2) for the dp array.
 */
public class PartitionProblem {

    public static boolean canPartition(int[] arr) {
        int total = 0;
        for (int v : arr) {
            total += v;
        }
        if (total % 2 != 0) {
            return false; // odd total can never be split into two equal halves
        }

        int target = total / 2;
        boolean[] dp = new boolean[target + 1];
        dp[0] = true;

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
        int[] balanced = {1, 5, 11, 5};
        int[] unbalanced = {1, 2, 3, 5};

        System.out.println("Partition Problem (Equal Subset Sum)");

        System.out.print("Array A: ");
        for (int v : balanced) {
            System.out.print(v + " ");
        }
        System.out.println();
        boolean resultA = canPartition(balanced);
        System.out.println("Can be partitioned into two equal-sum subsets: " + resultA);

        System.out.println();
        System.out.print("Array B: ");
        for (int v : unbalanced) {
            System.out.print(v + " ");
        }
        System.out.println();
        boolean resultB = canPartition(unbalanced);
        System.out.println("Can be partitioned into two equal-sum subsets: " + resultB);

        System.out.println();
        System.out.println("Final computed answer -> Array A partitionable: " + resultA
                + ", Array B partitionable: " + resultB);
    }
}
