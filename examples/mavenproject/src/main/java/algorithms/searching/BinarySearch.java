import java.util.Arrays;

/**
 * Binary Search
 *
 * What it does: finds the index of a target value in a sorted array of
 * integers, much faster than scanning element by element.
 *
 * Core idea: because the array is sorted, we can repeatedly look at the
 * middle element of the current search range and use a single comparison
 * to discard half of the remaining possibilities. If the middle element
 * equals the target, we're done. If the target is smaller, it can only be
 * in the left half, so we discard the right half (and the middle);
 * otherwise, the opposite. Repeat on the surviving half until either the
 * target is found or the search range becomes empty, meaning the target is
 * not present. Each comparison cuts the problem size roughly in half, which
 * is what gives this algorithm its logarithmic speed.
 *
 * Time complexity: O(log n) in the worst and average case, since the
 * search space halves on every comparison; O(1) best case (target is the
 * very first middle element checked).
 * Space complexity: O(1) extra space for the iterative version used here
 * (a recursive version would use O(log n) stack space instead).
 */
public class BinarySearch {

    public static int search(int[] sortedArr, int target) {
        int low = 0;
        int high = sortedArr.length - 1;

        while (low <= high) {
            int mid = low + (high - low) / 2;
            if (sortedArr[mid] == target) {
                return mid;
            } else if (sortedArr[mid] < target) {
                low = mid + 1; // target must be in the right half, if present
            } else {
                high = mid - 1; // target must be in the left half, if present
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        int[] data = {2, 5, 8, 12, 16, 23, 38, 56, 72, 91};
        int target = 23;
        System.out.println("Sorted array: " + Arrays.toString(data));
        int result = search(data, target);
        if (result != -1) {
            System.out.println("Found " + target + " at index " + result);
        } else {
            System.out.println(target + " not found in array");
        }
    }
}
