import java.util.Arrays;

/**
 * Ternary Search
 *
 * What it does: finds the index of a target value in a sorted array of
 * integers by splitting the search range into three parts instead of two.
 *
 * Core idea: like binary search, ternary search repeatedly shrinks the
 * range it needs to examine, but it picks two internal division points,
 * mid1 and mid2, that split the current range into three roughly equal
 * parts. It compares the target against the values at both of those
 * points: if it matches either, we're done. Otherwise, since the array is
 * sorted, we know which of the three segments the target must fall into
 * (left of mid1, between mid1 and mid2, or right of mid2), and we discard
 * the other two segments. Although this discards two-thirds of the range
 * per step (versus binary search's one-half), it does so with two
 * comparisons instead of one, so in practice it is not faster than binary
 * search -- it's mainly of academic/educational interest, and useful for
 * finding extrema in unimodal functions.
 *
 * Time complexity: O(log3 n) in the worst case, which has a larger
 * constant factor than binary search's O(log2 n) in practice because each
 * step does two comparisons instead of one.
 * Space complexity: O(1) extra space for the iterative version used here.
 */
public class TernarySearch {

    public static int search(int[] sortedArr, int target) {
        int low = 0;
        int high = sortedArr.length - 1;

        while (low <= high) {
            int third = (high - low) / 3;
            int mid1 = low + third;
            int mid2 = high - third;

            if (sortedArr[mid1] == target) {
                return mid1;
            }
            if (sortedArr[mid2] == target) {
                return mid2;
            }

            if (target < sortedArr[mid1]) {
                high = mid1 - 1;          // target is in the first third
            } else if (target > sortedArr[mid2]) {
                low = mid2 + 1;           // target is in the last third
            } else {
                low = mid1 + 1;           // target is in the middle third
                high = mid2 - 1;
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        int[] data = {2, 4, 7, 11, 16, 20, 25, 31, 36, 42, 50};
        int target = 31;
        System.out.println("Sorted array: " + Arrays.toString(data));
        int result = search(data, target);
        if (result != -1) {
            System.out.println("Found " + target + " at index " + result);
        } else {
            System.out.println(target + " not found in array");
        }
    }
}
