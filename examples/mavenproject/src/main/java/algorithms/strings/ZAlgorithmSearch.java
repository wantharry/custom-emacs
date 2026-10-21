/**
 * Z-ALGORITHM STRING SEARCH
 *
 * Problem: given a text T and a pattern P, find all starting indices in
 * T where P occurs as a substring, using the Z-algorithm.
 *
 * Core idea (matching logic): build a concatenated string
 * S = P + separator + T (the separator is a character guaranteed not to
 * appear in either P or T, so it can never falsely extend a match across
 * the boundary). Then compute the Z-array of S: Z[i] is the length of
 * the longest substring starting at i that matches a prefix of S. Any
 * position i (within the T portion of S) where Z[i] >= |P| means the
 * substring of S starting at i matches the first |P| characters of S --
 * i.e. matches the pattern P exactly -- which is exactly a pattern
 * occurrence in the text.
 *
 * Building the Z-array efficiently uses a sliding window [L, R]
 * representing the rightmost Z-box found so far (a Z-box is a substring
 * starting at some index matching a prefix of S, known to extend out to
 * R). For each new index i:
 *   - If i > R, we must directly compare characters from scratch: extend
 *     a match against S's prefix as far as possible, then set a new
 *     Z-box [L, R] = [i, i + Z[i] - 1] if Z[i] > 0.
 *   - If i <= R, position i falls INSIDE a known Z-box, so S[i..R] is
 *     known to equal a chunk of the prefix; specifically Z[i] is at
 *     least min(R - i + 1, Z[i - L]) (reusing already-computed
 *     information from the mirrored position i-L inside the prefix). If
 *     that minimum doesn't already run past R, Z[i] is exactly that
 *     value; otherwise we extend further by direct comparison beyond R
 *     and update the window.
 * This reuse of previously computed Z-values (instead of comparing from
 * scratch at every position) is what makes the whole array computable in
 * linear time.
 *
 * Time complexity: O(n + m) -- building the Z-array over the
 * concatenated string of length n + m + 1 is linear.
 * Space complexity: O(n + m) for the concatenated string and Z-array.
 */
import java.util.ArrayList;
import java.util.List;

public class ZAlgorithmSearch {

    private static int[] buildZArray(String s) {
        int n = s.length();
        int[] z = new int[n];
        int l = 0;
        int r = 0;
        for (int i = 1; i < n; i++) {
            if (i <= r) {
                z[i] = Math.min(r - i + 1, z[i - l]);
            }
            while (i + z[i] < n && s.charAt(z[i]) == s.charAt(i + z[i])) {
                z[i]++;
            }
            if (i + z[i] - 1 > r) {
                l = i;
                r = i + z[i] - 1;
            }
        }
        return z;
    }

    public static List<Integer> search(String text, String pattern) {
        List<Integer> matches = new ArrayList<>();
        int m = pattern.length();
        if (m == 0 || m > text.length()) {
            return matches;
        }

        String combined = pattern + "\u0001" + text; // separator not in pattern/text
        int[] z = buildZArray(combined);

        int offset = m + 1; // index in `combined` where the text portion starts
        for (int i = offset; i < combined.length(); i++) {
            if (z[i] >= m) {
                matches.add(i - offset);
            }
        }
        return matches;
    }

    public static void main(String[] args) {
        String text = "AABAACAADAABAABA";
        String pattern = "AABA";

        System.out.println("Z-Algorithm String Search");
        System.out.println("Text:    " + text);
        System.out.println("Pattern: " + pattern);

        List<Integer> result = search(text, pattern);
        System.out.println();
        System.out.println("Final computed answer -> Match starting indices: " + result);
    }
}
