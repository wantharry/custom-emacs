/**
 * EDIT DISTANCE (LEVENSHTEIN DISTANCE) -- DYNAMIC PROGRAMMING
 *
 * Problem: given two strings A (length m) and B (length n), find the
 * minimum number of single-character insertions, deletions, and
 * substitutions needed to transform A into B.
 *
 * Core idea (recurrence relation): let dp[i][j] be the edit distance
 * between the prefix A[0..i-1] and the prefix B[0..j-1]. Consider the
 * last characters of those prefixes:
 *   - If A[i-1] == B[j-1], they already match, so no edit is needed for
 *     this position: dp[i][j] = dp[i-1][j-1].
 *   - Otherwise we must pay for one edit, and we take whichever of the
 *     three possible operations is cheapest:
 *       insert into A (match A's current prefix against one fewer char
 *         of B):       dp[i][j-1] + 1
 *       delete from A (drop A's last char):
 *                      dp[i-1][j] + 1
 *       substitute (fix the mismatched last chars and move both back):
 *                      dp[i-1][j-1] + 1
 *     dp[i][j] = 1 + min(dp[i][j-1], dp[i-1][j], dp[i-1][j-1])
 * Base cases: dp[0][j] = j (turn empty string into B's first j chars by
 * j insertions) and dp[i][0] = i (delete all i characters of A).
 *
 * This works because any sequence of edits transforming A's prefix into
 * B's prefix must end in one of those three operations (or no operation,
 * if the last characters already match), and whichever it is, the rest
 * of the edits solve a strictly smaller sub-problem.
 *
 * Time complexity: O(m * n) to fill the table.
 * Space complexity: O(m * n) (reducible to O(min(m,n)) with a rolling
 * two-row array).
 */
public class EditDistance {

    public static int editDistance(String a, String b) {
        int m = a.length();
        int n = b.length();
        int[][] dp = new int[m + 1][n + 1];

        for (int i = 0; i <= m; i++) {
            dp[i][0] = i;
        }
        for (int j = 0; j <= n; j++) {
            dp[0][j] = j;
        }

        for (int i = 1; i <= m; i++) {
            for (int j = 1; j <= n; j++) {
                if (a.charAt(i - 1) == b.charAt(j - 1)) {
                    dp[i][j] = dp[i - 1][j - 1];
                } else {
                    int insert = dp[i][j - 1] + 1;
                    int delete = dp[i - 1][j] + 1;
                    int substitute = dp[i - 1][j - 1] + 1;
                    dp[i][j] = Math.min(insert, Math.min(delete, substitute));
                }
            }
        }
        return dp[m][n];
    }

    public static void main(String[] args) {
        String a = "kitten";
        String b = "sitting";

        System.out.println("Edit Distance (Levenshtein)");
        System.out.println("String A: " + a);
        System.out.println("String B: " + b);

        int result = editDistance(a, b);
        System.out.println();
        System.out.println("Final computed answer -> Edit distance: " + result);
    }
}
