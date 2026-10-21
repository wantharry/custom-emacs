import java.util.Arrays;

/**
 * Linear Search
 *
 * What it does: finds the index of a target value in an array of integers,
 * working on any array -- sorted or not.
 *
 * Core idea: there is no shortcut here -- simply check every element one by
 * one, from the start of the array to the end, comparing it against the
 * target. As soon as a match is found, return its index immediately. If
 * the loop finishes without finding a match, the target isn't in the
 * array, so return -1. This is the most general search possible, since it
 * makes no assumptions whatsoever about the array's ordering.
 *
 * Time complexity: O(n) in the worst and average case (the target may be
 * the last element, or absent, requiring a full scan); O(1) best case (the
 * target is the first element).
 * Space complexity: O(1) extra space -- just a loop counter.
 */
public class LinearSearch {

    public static int search(int[] arr, int target) {
        for (int i = 0; i < arr.length; i++) {
            if (arr[i] == target) {
                return i;
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        int[] data = {64, 34, 25, 12, 22, 11, 90};
        int target = 22;
        System.out.println("Array: " + Arrays.toString(data));
        int result = search(data, target);
        if (result != -1) {
            System.out.println("Found " + target + " at index " + result);
        } else {
            System.out.println(target + " not found in array");
        }
    }
}
