/**
 * ANAGRAM CHECK -- CHARACTER FREQUENCY COUNTING
 *
 * Problem: given two strings, determine whether one is an anagram of the
 * other -- i.e. both strings use exactly the same multiset of
 * characters, just possibly rearranged (same letters, same counts,
 * different order allowed).
 *
 * Core idea (matching logic): two strings are anagrams of each other if
 * and only if they have identical character frequency counts. So:
 *   1. If the lengths differ, they can't possibly be anagrams -- fail
 *      fast.
 *   2. Otherwise, count how many times each character appears in the
 *      first string (incrementing a counter per character), then "undo"
 *      those counts by decrementing for each character seen in the
 *      second string.
 *   3. If the strings are true anagrams, every increment from string 1
 *      is exactly cancelled by a decrement from string 2, leaving all
 *      counters at zero. If any counter ends up non-zero, some character
 *      appeared a different number of times in the two strings, so they
 *      are NOT anagrams.
 * Using a fixed-size array indexed by character code (here restricted to
 * lowercase 'a'-'z' for simplicity) avoids the overhead of a hash map
 * while still being O(1) per character to update and check.
 *
 * Time complexity: O(n) where n is the string length -- one pass to
 * count, one pass to decrement, one pass to verify all zero.
 * Space complexity: O(1) -- the counting array has a fixed size (26 for
 * lowercase English letters) independent of input length.
 */
public class AnagramCheck {

    public static boolean isAnagram(String a, String b) {
        if (a.length() != b.length()) {
            return false;
        }
        int[] counts = new int[26];
        for (int i = 0; i < a.length(); i++) {
            counts[Character.toLowerCase(a.charAt(i)) - 'a']++;
            counts[Character.toLowerCase(b.charAt(i)) - 'a']--;
        }
        for (int count : counts) {
            if (count != 0) {
                return false;
            }
        }
        return true;
    }

    public static void main(String[] args) {
        String a = "listen";
        String b = "silent";
        String c = "hello";

        System.out.println("Anagram Check (Character Frequency Counting)");
        System.out.println("\"" + a + "\" vs \"" + b + "\" -> isAnagram = " + isAnagram(a, b));
        System.out.println("\"" + a + "\" vs \"" + c + "\" -> isAnagram = " + isAnagram(a, c));

        boolean result = isAnagram(a, b);
        System.out.println();
        System.out.println("Final computed answer -> \"" + a + "\" and \"" + b + "\" are anagrams: " + result);
    }
}
