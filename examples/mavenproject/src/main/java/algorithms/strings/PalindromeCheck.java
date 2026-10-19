/**
 * PALINDROME CHECK -- TWO-POINTER COMPARISON
 *
 * Problem: given a string, determine whether it reads the same forwards
 * and backwards (ignoring case and non-alphanumeric characters, so that
 * phrases like "A man, a plan, a canal: Panama" are correctly recognized
 * as palindromes).
 *
 * Core idea (matching logic): use two pointers, one starting at the
 * beginning of the string (left) and one at the end (right). Repeatedly:
 *   1. Advance `left` forward past any character that isn't a letter or
 *      digit, and advance `right` backward past any such character
 *      (so punctuation and spaces are simply skipped over, not
 *      compared).
 *   2. Compare the characters at `left` and `right`, case-insensitively.
 *      If they differ, the string is not a palindrome -- stop
 *      immediately.
 *   3. If they match, move `left` one step inward and `right` one step
 *      inward, and repeat.
 *   4. If `left` and `right` meet or cross without ever finding a
 *      mismatch, every pair of mirrored characters matched, so the
 *      string IS a palindrome.
 * This is correct because a string is a palindrome exactly when every
 * character at distance d from the start equals the character at
 * distance d from the end, for every d -- which is precisely what the
 * two pointers check, one mirrored pair at a time, meeting in the
 * middle.
 *
 * Time complexity: O(n) -- each pointer moves across the string once, so
 * at most n total character comparisons/skips.
 * Space complexity: O(1) -- only the two index variables are used (no
 * copy of the string is made).
 */
public class PalindromeCheck {

    public static boolean isPalindrome(String s) {
        int left = 0;
        int right = s.length() - 1;

        while (left < right) {
            while (left < right && !Character.isLetterOrDigit(s.charAt(left))) {
                left++;
            }
            while (left < right && !Character.isLetterOrDigit(s.charAt(right))) {
                right--;
            }
            if (Character.toLowerCase(s.charAt(left)) != Character.toLowerCase(s.charAt(right))) {
                return false;
            }
            left++;
            right--;
        }
        return true;
    }

    public static void main(String[] args) {
        String a = "A man, a plan, a canal: Panama";
        String b = "Not a palindrome here";

        System.out.println("Palindrome Check (Two-Pointer Comparison)");
        System.out.println("\"" + a + "\" -> isPalindrome = " + isPalindrome(a));
        System.out.println("\"" + b + "\" -> isPalindrome = " + isPalindrome(b));

        boolean result = isPalindrome(a);
        System.out.println();
        System.out.println("Final computed answer -> \"" + a + "\" is a palindrome: " + result);
    }
}
