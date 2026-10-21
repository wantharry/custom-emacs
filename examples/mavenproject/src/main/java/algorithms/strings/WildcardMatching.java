/**
 * WILDCARD PATTERN MATCHING -- DYNAMIC PROGRAMMING
 *
 * Problem: given a text string S and a pattern P that may contain the
 * wildcards '?' (matches any single character) and '*' (matches any
 * sequence of characters, including the empty sequence), determine
 * whether P matches the entirety of S.
 *
 * Core idea (matching logic / recurrence relation): let dp[i][j] be true
 * if the first i characters of S match the first j characters of P.
 * Consider the j-th character of the pattern (P[j-1]):
 *   - If P[j-1] is a normal character: it must equal S[i-1] exactly, and
 *     the rest must already match: dp[i][j] = dp[i-1][j-1] AND
 *     (S[i-1] == P[j-1]).
 *   - If P[j-1] is '?': it matches any one character, so just require
 *     the rest to already match: dp[i][j] = dp[i-1][j-1] (as long as
 *     i > 0, since '?' must consume one character of S).
 *   - If P[j-1] is '*': it can match EITHER zero characters of S (so
 *     dp[i][j] = dp[i][j-1], treat '*' as consumed but matching
 *     nothing) OR it can match one more character of S while still
 *     being "in effect" for future characters too (so dp[i][j] =
 *     dp[i-1][j], the '*' absorbs S[i-1] and remains available):
 *     dp[i][j] = dp[i][j-1] OR dp[i-1][j].
 * Base cases: dp[0][0] = true (empty pattern matches empty string).
 * dp[0][j] = true only if P[0..j-1] consists entirely of '*' characters
 * (a pattern of only stars can match the empty string). dp[i][0] = false
 * for i > 0 (a non-empty string can never match an empty pattern).
 *
 * Time complexity: O(n * m) where n = |S|, m = |P| -- one O(1) decision
 * per table cell.
 * Space complexity: O(n * m) for the dp table (reducible to O(m) with a
 * rolling 1D array).
 */
public class WildcardMatching {

    public static boolean isMatch(String s, String p) {
        int n = s.length();
        int m = p.length();
        boolean[][] dp = new boolean[n + 1][m + 1];
        dp[0][0] = true;

        for (int j = 1; j <= m; j++) {
            if (p.charAt(j - 1) == '*') {
                dp[0][j] = dp[0][j - 1];
            }
        }

        for (int i = 1; i <= n; i++) {
            for (int j = 1; j <= m; j++) {
                char pc = p.charAt(j - 1);
                if (pc == '*') {
                    dp[i][j] = dp[i][j - 1] || dp[i - 1][j];
                } else if (pc == '?' || pc == s.charAt(i - 1)) {
                    dp[i][j] = dp[i - 1][j - 1];
                } else {
                    dp[i][j] = false;
                }
            }
        }
        return dp[n][m];
    }

    public static void main(String[] args) {
        String text1 = "adceb";
        String pattern1 = "*a*b";

        String text2 = "acdcb";
        String pattern2 = "a*c?b";

        System.out.println("Wildcard Pattern Matching (Dynamic Programming)");
        System.out.println("Text: \"" + text1 + "\", Pattern: \"" + pattern1 + "\" -> match = "
                + isMatch(text1, pattern1));
        System.out.println("Text: \"" + text2 + "\", Pattern: \"" + pattern2 + "\" -> match = "
                + isMatch(text2, pattern2));

        boolean result = isMatch(text1, pattern1);
        System.out.println();
        System.out.println("Final computed answer -> \"" + text1 + "\" matches \"" + pattern1 + "\": " + result);
    }
}
