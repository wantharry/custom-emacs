/**
 * COMBINATIONS COUNT: C(n, r) = n! / (r! * (n - r)!)
 *
 * What it does:
 *   Counts the number of ways to choose r items from a set of n distinct
 *   items where ORDER DOES NOT MATTER (e.g. choosing a 5-person
 *   committee from 20 people).
 *
 * Core idea / how it works:
 *   Start from the permutations count P(n, r) = n*(n-1)*...*(n-r+1),
 *   which counts ordered selections, then divide by r! because each
 *   unordered group of r items can be arranged in r! different orders
 *   that all count as the same combination. To stay in integer
 *   arithmetic without huge intermediate values, the computation
 *   multiplies and divides incrementally, one step at a time:
 *   result = result * (n - i) / (i + 1) for i = 0..r-1. This works
 *   exactly because the running product at each step is always evenly
 *   divisible (a standard trick for computing binomial coefficients
 *   iteratively).
 *
 * Time complexity:  O(r)  -- r multiply/divide steps; use the smaller of
 *                            r and n-r to minimize work.
 * Space complexity: O(1).
 */
public class CombinationsCount {

    public static long combinations(int n, int r) {
        if (r < 0 || r > n) throw new IllegalArgumentException("require 0 <= r <= n");
        r = Math.min(r, n - r); // exploit symmetry C(n, r) == C(n, n - r)
        long result = 1;
        for (int i = 0; i < r; i++) {
            result = result * (n - i) / (i + 1);
        }
        return result;
    }

    public static void main(String[] args) {
        int[][] cases = {{20, 5}, {10, 0}, {10, 10}, {6, 3}, {52, 5}};
        System.out.println("Computing C(n, r) -- combinations of r items from n:");
        for (int[] c : cases) {
            System.out.println("  C(" + c[0] + ", " + c[1] + ") = " + combinations(c[0], c[1]));
        }
    }
}
