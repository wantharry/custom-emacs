/**
 * KNUTH-MORRIS-PRATT (KMP) STRING SEARCH ALGORITHM
 *
 * Problem: given a text T (length n) and a pattern P (length m), find
 * all starting indices in T where P occurs as a substring.
 *
 * Core idea (matching logic): a naive search re-compares the pattern
 * from scratch after every mismatch, which can cost O(n*m) in the worst
 * case. KMP avoids this by preprocessing the pattern into a "failure
 * function" (also called the LPS array: Longest Proper Prefix which is
 * also a Suffix), lps[i] = the length of the longest proper prefix of
 * P[0..i] that is also a suffix of P[0..i]. This encodes exactly how
 * much of the pattern we've already matched can be "reused" after a
 * mismatch, so we never need to re-examine characters of the text we've
 * already looked at.
 *
 * Building the LPS array: we compare the pattern against itself. Keep a
 * pointer `len` = length of the current matching prefix/suffix. For each
 * new position i, while P[i] matches P[len], extend (len++). On a
 * mismatch with len > 0, fall back to lps[len-1] (reusing the previously
 * computed partial match) instead of resetting to 0 outright -- this
 * fallback step is itself what gives KMP its "do less redundant work"
 * power, applied recursively.
 *
 * Searching: scan T with pointer i, and a pattern pointer j. While
 * characters match, advance both. On a mismatch (or a full match of
 * length m, meaning we found an occurrence), instead of resetting j to 0
 * we set j = lps[j-1], skipping all the text comparisons we already know
 * must succeed because of the structure captured in the LPS array. i
 * never moves backward, so the text is scanned once.
 *
 * Time complexity: O(n + m) -- O(m) to build the LPS array, O(n) to scan
 * the text, with every text character examined (amortized) a constant
 * number of times.
 * Space complexity: O(m) for the LPS array.
 */
import java.util.ArrayList;
import java.util.List;

public class KMPStringSearch {

    private static int[] buildLpsArray(String pattern) {
        int m = pattern.length();
        int[] lps = new int[m];
        int len = 0; // length of the previous longest prefix-suffix match
        int i = 1;
        while (i < m) {
            if (pattern.charAt(i) == pattern.charAt(len)) {
                len++;
                lps[i] = len;
                i++;
            } else if (len > 0) {
                len = lps[len - 1]; // fall back, reusing prior partial-match info
            } else {
                lps[i] = 0;
                i++;
            }
        }
        return lps;
    }

    public static List<Integer> search(String text, String pattern) {
        List<Integer> matches = new ArrayList<>();
        int n = text.length();
        int m = pattern.length();
        if (m == 0 || m > n) {
            return matches;
        }

        int[] lps = buildLpsArray(pattern);
        int i = 0; // index into text
        int j = 0; // index into pattern

        while (i < n) {
            if (text.charAt(i) == pattern.charAt(j)) {
                i++;
                j++;
                if (j == m) {
                    matches.add(i - j); // full match found, starting at i-j
                    j = lps[j - 1];
                }
            } else if (j > 0) {
                j = lps[j - 1];
            } else {
                i++;
            }
        }
        return matches;
    }

    public static void main(String[] args) {
        String text = "ABABDABACDABABCABAB";
        String pattern = "ABABCABAB";

        System.out.println("KMP String Search");
        System.out.println("Text:    " + text);
        System.out.println("Pattern: " + pattern);

        List<Integer> result = search(text, pattern);
        System.out.println();
        System.out.println("Final computed answer -> Match starting indices: " + result);
    }
}
