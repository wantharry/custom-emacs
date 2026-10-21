/**
 * RABIN-KARP STRING SEARCH ALGORITHM
 *
 * Problem: given a text T (length n) and a pattern P (length m), find
 * all starting indices in T where P occurs as a substring.
 *
 * Core idea (matching logic): instead of comparing characters directly
 * at every position, Rabin-Karp computes a numeric hash of the pattern
 * and compares it against the hash of every length-m window of the text
 * (a "rolling hash"). Hashes are cheap to compare, and a ROLLING hash can
 * be updated in O(1) when the window slides by one position, instead of
 * recomputing the hash of the whole new window from scratch.
 *
 * We treat each substring as a number in some base (here, a prime base,
 * treating characters as digits), reduced modulo a large prime to keep
 * the numbers small. For a window text[i..i+m-1], its hash is:
 *   hash = (text[i]*base^(m-1) + text[i+1]*base^(m-2) + ... + text[i+m-1]) mod MOD
 * Sliding the window from i to i+1 means removing the contribution of
 * text[i] and adding text[i+m]:
 *   newHash = ((hash - text[i]*base^(m-1)) * base + text[i+m]) mod MOD
 * This update is O(1), so computing all window hashes costs O(n) total.
 *
 * Because hashes can collide (two different strings hashing to the same
 * value) even modulo a large prime, whenever a window's hash matches the
 * pattern's hash we do a final direct character-by-character comparison
 * to confirm it's a true match, not a false positive -- this verification
 * step is essential for correctness.
 *
 * Time complexity: O(n + m) on average (hash comparisons are O(1)
 * amortized, with occasional O(m) verification on hash matches); O(n*m)
 * worst case if there are many hash collisions requiring verification.
 * Space complexity: O(1) beyond the output list (hashes are computed
 * incrementally, no extra arrays needed).
 */
import java.util.ArrayList;
import java.util.List;

public class RabinKarpSearch {

    private static final long BASE = 256L;
    private static final long MOD = 1_000_000_007L;

    public static List<Integer> search(String text, String pattern) {
        List<Integer> matches = new ArrayList<>();
        int n = text.length();
        int m = pattern.length();
        if (m == 0 || m > n) {
            return matches;
        }

        // highestPower = BASE^(m-1) mod MOD, used to "remove" the leading
        // character's contribution when the window slides forward.
        long highestPower = 1L;
        for (int i = 0; i < m - 1; i++) {
            highestPower = (highestPower * BASE) % MOD;
        }

        long patternHash = 0L;
        long windowHash = 0L;
        for (int i = 0; i < m; i++) {
            patternHash = (patternHash * BASE + pattern.charAt(i)) % MOD;
            windowHash = (windowHash * BASE + text.charAt(i)) % MOD;
        }

        for (int i = 0; ; i++) {
            if (windowHash == patternHash && text.regionMatches(i, pattern, 0, m)) {
                matches.add(i);
            }
            int next = i + m;
            if (next >= n) {
                break;
            }
            // Roll the hash: drop text[i], add text[next].
            windowHash = (windowHash - text.charAt(i) * highestPower % MOD + MOD) % MOD;
            windowHash = (windowHash * BASE + text.charAt(next)) % MOD;
        }
        return matches;
    }

    public static void main(String[] args) {
        String text = "ABCCDABCABCABC";
        String pattern = "ABCABC";

        System.out.println("Rabin-Karp String Search");
        System.out.println("Text:    " + text);
        System.out.println("Pattern: " + pattern);

        List<Integer> result = search(text, pattern);
        System.out.println();
        System.out.println("Final computed answer -> Match starting indices: " + result);
    }
}
