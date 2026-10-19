/**
 * PERMUTATIONS COUNT: P(n, r) = n! / (n - r)!
 *
 * What it does:
 *   Counts the number of ways to arrange r items chosen from a set of n
 *   distinct items, where ORDER MATTERS (e.g. assigning 1st/2nd/3rd place
 *   medals to 3 of 10 runners).
 *
 * Core idea / how it works:
 *   Think of filling r ordered slots one at a time: there are n choices
 *   for the first slot, (n-1) remaining choices for the second slot (one
 *   is used up), (n-2) for the third, and so on down to (n-r+1) for the
 *   last slot. Multiplying those r shrinking choices together gives
 *   n * (n-1) * ... * (n-r+1), which is exactly n! / (n-r)!. The
 *   implementation multiplies that shrinking sequence directly instead
 *   of computing two full factorials and dividing, which avoids
 *   needlessly huge intermediate numbers.
 *
 * Time complexity:  O(r)  -- r multiplications.
 * Space complexity: O(1).
 */
public class PermutationsCount {

    public static long permutations(int n, int r) {
        if (r < 0 || r > n) throw new IllegalArgumentException("require 0 <= r <= n");
        long result = 1;
        for (int i = 0; i < r; i++) {
            result *= (n - i);
        }
        return result;
    }

    public static void main(String[] args) {
        int[][] cases = {{10, 3}, {5, 5}, {6, 0}, {8, 2}, {4, 4}};
        System.out.println("Computing P(n, r) -- permutations of r items from n:");
        for (int[] c : cases) {
            System.out.println("  P(" + c[0] + ", " + c[1] + ") = " + permutations(c[0], c[1]));
        }
    }
}
