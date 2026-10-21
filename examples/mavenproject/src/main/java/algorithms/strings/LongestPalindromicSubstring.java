/**
 * LONGEST PALINDROMIC SUBSTRING -- EXPAND AROUND CENTER
 *
 * Problem: given a string S, find the longest contiguous substring of S
 * that reads the same forwards and backwards (a palindrome).
 *
 * Core idea (matching logic): every palindrome has a center. For a
 * palindrome of ODD length, the center is a single character; for a
 * palindrome of EVEN length, the center is the gap between two adjacent
 * characters. There are exactly (2n - 1) possible centers in a string of
 * length n (n single-character centers, n-1 between-character centers).
 * For each possible center, we "expand" outward symmetrically with two
 * pointers (left moving left, right moving right) as long as the
 * characters at both pointers match -- the matching logic is simply:
 * keep expanding while S[left] == S[right], then the longest palindrome
 * centered there spans (left+1 .. right-1) once the loop stops (the
 * first mismatch, or going out of bounds, means left/right have gone one
 * step too far).
 * We try every center, track the longest palindrome found, and that's
 * the answer -- this works because any palindrome IS centered somewhere,
 * so checking every possible center is exhaustive and correct.
 *
 * (A more advanced linear-time method, Manacher's algorithm, exists, but
 * expand-around-center is the clearest illustration of the technique and
 * is simple to implement correctly.)
 *
 * Time complexity: O(n^2) -- n possible centers, each expansion can take
 * up to O(n) steps.
 * Space complexity: O(1) extra space (beyond the input and the returned
 * substring).
 */
public class LongestPalindromicSubstring {

    public static String longestPalindrome(String s) {
        if (s == null || s.isEmpty()) {
            return "";
        }
        int bestStart = 0;
        int bestLength = 1;

        for (int center = 0; center < s.length(); center++) {
            int[] odd = expandAroundCenter(s, center, center);     // odd-length palindromes
            int[] even = expandAroundCenter(s, center, center + 1); // even-length palindromes

            if (odd[1] > bestLength) {
                bestLength = odd[1];
                bestStart = odd[0];
            }
            if (even[1] > bestLength) {
                bestLength = even[1];
                bestStart = even[0];
            }
        }
        return s.substring(bestStart, bestStart + bestLength);
    }

    // Returns {startIndex, length} of the longest palindrome centered
    // between indices left and right (left == right for odd-length,
    // right == left + 1 for even-length).
    private static int[] expandAroundCenter(String s, int left, int right) {
        while (left >= 0 && right < s.length() && s.charAt(left) == s.charAt(right)) {
            left--;
            right++;
        }
        int start = left + 1;
        int length = right - left - 1;
        return new int[] {start, length};
    }

    public static void main(String[] args) {
        String s = "babadforgeeksskeegfor";

        System.out.println("Longest Palindromic Substring (Expand Around Center)");
        System.out.println("Input string: " + s);

        String result = longestPalindrome(s);
        System.out.println();
        System.out.println("Final computed answer -> Longest palindromic substring: \"" + result + "\" (length "
                + result.length() + ")");
    }
}
