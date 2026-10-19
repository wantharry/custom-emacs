/**
 * STRING REVERSAL -- IN-PLACE TWO-POINTER SWAP
 *
 * Problem: given a string, produce the string with its characters in
 * reverse order.
 *
 * Core idea (matching logic): convert the string to a mutable character
 * array, then use two pointers -- `left` starting at index 0 and `right`
 * starting at the last index. Swap the characters at `left` and `right`,
 * then move `left` one step forward and `right` one step backward.
 * Repeat until the pointers meet or cross in the middle. Each swap
 * correctly places the i-th character from the start into the i-th
 * position from the end, and vice versa, which is exactly the
 * definition of reversal: the character originally at position i ends
 * up at position (length - 1 - i).
 * We only need to go as far as the midpoint, since by the time `left`
 * and `right` meet every pair has already been swapped exactly once
 * (swapping a pair twice would undo the reversal).
 *
 * Time complexity: O(n) -- each of the n characters is touched a
 * constant number of times (one swap involves two characters, and there
 * are n/2 swaps).
 * Space complexity: O(n) for the output character array/string (O(1)
 * *extra* space beyond the copy being built, since the swap itself uses
 * no auxiliary storage besides one temporary variable).
 */
public class StringReversal {

    public static String reverse(String s) {
        char[] chars = s.toCharArray();
        int left = 0;
        int right = chars.length - 1;

        while (left < right) {
            char temp = chars[left];
            chars[left] = chars[right];
            chars[right] = temp;
            left++;
            right--;
        }
        return new String(chars);
    }

    public static void main(String[] args) {
        String input = "Hello, Dynamic Programming World!";

        System.out.println("String Reversal (In-Place Two-Pointer Swap)");
        System.out.println("Original: " + input);

        String result = reverse(input);
        System.out.println();
        System.out.println("Final computed answer -> Reversed string: " + result);
    }
}
