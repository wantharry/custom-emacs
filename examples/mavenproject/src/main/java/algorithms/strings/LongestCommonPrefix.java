/**
 * LONGEST COMMON PREFIX -- HORIZONTAL SCANNING
 *
 * Problem: given an array of strings, find the longest string that is a
 * prefix of every string in the array (returning an empty string if
 * there is no common prefix, e.g. if the array is empty or the strings
 * share no leading characters).
 *
 * Core idea (matching logic): start by assuming the first string in the
 * array is the candidate answer. Then repeatedly shrink that candidate
 * to be a prefix of the NEXT string as well, one string at a time
 * ("horizontal scanning" -- we scan across the array of strings,
 * shrinking the common prefix as we go, rather than scanning down
 * character columns across all strings at once). To shrink the
 * candidate against a new string, keep trimming characters off the end
 * of the candidate until it actually is a prefix of that string (using
 * String.startsWith, or equivalently comparing character by character).
 * Once the candidate has been checked against every string in the
 * array, whatever remains is a prefix of all of them -- and it's the
 * LONGEST such prefix, because we only ever trimmed it when a longer
 * version provably failed to match some string.
 * If at any point the candidate becomes empty, no common prefix exists
 * at all, and we can stop early.
 *
 * Time complexity: O(S) where S is the sum of all characters across all
 * strings in the worst case (each trimming step is proportional to the
 * current candidate length, and in total work is bounded by comparing
 * each string's characters against the shrinking candidate).
 * Space complexity: O(1) extra space (beyond the returned prefix
 * string), since we only ever shrink the existing candidate.
 */
public class LongestCommonPrefix {

    public static String longestCommonPrefix(String[] strs) {
        if (strs == null || strs.length == 0) {
            return "";
        }

        String prefix = strs[0];
        for (int i = 1; i < strs.length; i++) {
            while (!strs[i].startsWith(prefix)) {
                prefix = prefix.substring(0, prefix.length() - 1);
                if (prefix.isEmpty()) {
                    return "";
                }
            }
        }
        return prefix;
    }

    public static void main(String[] args) {
        String[] words = {"flower", "flow", "flight"};

        System.out.println("Longest Common Prefix (Horizontal Scanning)");
        System.out.print("Words: ");
        for (String w : words) {
            System.out.print("\"" + w + "\" ");
        }
        System.out.println();

        String result = longestCommonPrefix(words);
        System.out.println();
        System.out.println("Final computed answer -> Longest common prefix: \"" + result + "\"");
    }
}
