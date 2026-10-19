/**
 * LONGEST COMMON SUBSEQUENCE (LCS) -- DYNAMIC PROGRAMMING
 *
 * Problem: given two strings A (length m) and B (length n), find the
 * length (and, here, the actual text) of the longest subsequence common
 * to both. A subsequence keeps the relative order of characters but need
 * not be contiguous (e.g. "ACE" is a subsequence of "ABCDE").
 *
 * Core idea (recurrence relation): let dp[i][j] be the LCS length of the
 * prefixes A[0..i-1] and B[0..j-1]. Compare the last characters of those
 * prefixes:
 *   - If A[i-1] == B[j-1], that character can always be part of an
 *     optimal common subsequence, so dp[i][j] = dp[i-1][j-1] + 1.
 *   - Otherwise, the LCS of the two prefixes must skip the last character
 *     of A, or the last character of B (or both), so we take the best of
 *     dropping either one: dp[i][j] = max(dp[i-1][j], dp[i][j-1]).
 * Base case: dp[0][j] = dp[i][0] = 0 (an empty string has no common
 * subsequence with anything). This works because the LCS of two strings
 * can always be decided by looking only at how their last characters
 * relate, reducing to a sub-problem on shorter prefixes.
 *
 * To recover the actual subsequence text, we walk back through the table
 * from dp[m][n]: whenever A[i-1] == B[j-1] we record that character and
 * move diagonally; otherwise we move toward whichever of dp[i-1][j] or
 * dp[i][j-1] produced the current value.
 *
 * Time complexity: O(m * n) to fill the table.
 * Space complexity: O(m * n) for the table (can be reduced to O(min(m,n))
 * if only the length, not the reconstructed text, is needed).
 */
public class LongestCommonSubsequence {

    public static int[][] buildTable(String a, String b) {
        int m = a.length();
        int n = b.length();
        int[][] dp = new int[m + 1][n + 1];

        for (int i = 1; i <= m; i++) {
            for (int j = 1; j <= n; j++) {
                if (a.charAt(i - 1) == b.charAt(j - 1)) {
                    dp[i][j] = dp[i - 1][j - 1] + 1;
                } else {
                    dp[i][j] = Math.max(dp[i - 1][j], dp[i][j - 1]);
                }
            }
        }
        return dp;
    }

    public static String reconstruct(String a, String b, int[][] dp) {
        StringBuilder sb = new StringBuilder();
        int i = a.length();
        int j = b.length();
        while (i > 0 && j > 0) {
            if (a.charAt(i - 1) == b.charAt(j - 1)) {
                sb.append(a.charAt(i - 1));
                i--;
                j--;
            } else if (dp[i - 1][j] >= dp[i][j - 1]) {
                i--;
            } else {
                j--;
            }
        }
        return sb.reverse().toString();
    }

    public static void main(String[] args) {
        String a = "ABCBDAB";
        String b = "BDCABA";

        int[][] dp = buildTable(a, b);
        int length = dp[a.length()][b.length()];
        String sequence = reconstruct(a, b, dp);

        System.out.println("Longest Common Subsequence");
        System.out.println("String A: " + a);
        System.out.println("String B: " + b);
        System.out.println("LCS text: " + sequence);
        System.out.println();
        System.out.println("Final computed answer -> LCS length: " + length);
    }
}
