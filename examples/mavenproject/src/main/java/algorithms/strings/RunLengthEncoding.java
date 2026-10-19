/**
 * RUN-LENGTH ENCODING (RLE)
 *
 * Problem: compress a string by replacing consecutive runs of the same
 * character with the character followed by the length of its run (e.g.
 * "aaabbbccd" becomes "a3b3c2d1"), and decode such an encoded string
 * back into the original.
 *
 * Core idea (matching logic):
 *   Encoding: scan the string left to right while tracking the current
 *   run's character and a count. As long as the next character MATCHES
 *   the current run's character, just increment the count. The moment a
 *   DIFFERENT character is seen (a mismatch), the current run is
 *   finished: append (character + count) to the output, then start a
 *   new run with the new character and count 1. After the loop ends,
 *   flush whatever run is still in progress (the last run never gets
 *   closed out by a mismatch, since there's no character after it).
 *
 *   Decoding: walk through the encoded string two tokens at a time -- a
 *   character, followed by a run of digits representing its count
 *   (support multi-digit counts by reading digits until a non-digit is
 *   found). Append that character to the output exactly `count` times,
 *   then move on to the next character/count pair.
 *
 * Time complexity: O(n) for encoding (n = length of input string) and
 * O(m) for decoding (m = length of the decoded output), since each
 * character is processed/emitted a constant number of times.
 * Space complexity: O(n) for the encoded or decoded output string being
 * built.
 */
public class RunLengthEncoding {

    public static String encode(String input) {
        if (input.isEmpty()) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        char currentChar = input.charAt(0);
        int count = 1;

        for (int i = 1; i < input.length(); i++) {
            char c = input.charAt(i);
            if (c == currentChar) {
                count++;
            } else {
                sb.append(currentChar).append(count);
                currentChar = c;
                count = 1;
            }
        }
        sb.append(currentChar).append(count); // flush the final run
        return sb.toString();
    }

    public static String decode(String encoded) {
        StringBuilder sb = new StringBuilder();
        int i = 0;
        while (i < encoded.length()) {
            char c = encoded.charAt(i);
            i++;
            int numStart = i;
            while (i < encoded.length() && Character.isDigit(encoded.charAt(i))) {
                i++;
            }
            int count = Integer.parseInt(encoded.substring(numStart, i));
            for (int k = 0; k < count; k++) {
                sb.append(c);
            }
        }
        return sb.toString();
    }

    public static void main(String[] args) {
        String original = "aaabbbccccd";

        System.out.println("Run-Length Encoding");
        System.out.println("Original string: " + original);

        String encoded = encode(original);
        System.out.println("Encoded string:  " + encoded);

        String decoded = decode(encoded);
        System.out.println("Decoded string:  " + decoded);

        boolean roundTripOk = decoded.equals(original);
        System.out.println();
        System.out.println("Final computed answer -> Encoded: \"" + encoded + "\", round-trip correct: "
                + roundTripOk);
    }
}
