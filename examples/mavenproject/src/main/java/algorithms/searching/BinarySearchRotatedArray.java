import java.util.Arrays;

/**
 * Binary Search on a Rotated Sorted Array
 *
 * What it does: finds the index of a target value in an array that was
 * sorted in ascending order and then rotated at some unknown pivot point
 * (e.g. [4, 5, 6, 7, 0, 1, 2] is [0, 1, 2, 4, 5, 6, 7] rotated at index 4),
 * without needing to first "un-rotate" or search it linearly.
 *
 * Core idea: even though the whole array is not sorted, at any given
 * midpoint, at least one of the two halves [low, mid] or [mid, high] must
 * still be internally sorted (a rotation only breaks the order at one
 * "seam"). So at each step, compute mid, and first figure out which half
 * is the sorted one by comparing arr[low] to arr[mid]. Then check whether
 * the target falls within that sorted half's value range -- if it does,
 * recurse/iterate into that half; otherwise, the target (if present) must
 * be in the other half, so iterate into that one instead. This keeps the
 * halving behavior of ordinary binary search while correctly handling the
 * single rotation seam.
 *
 * Time complexity: O(log n) in the worst, average, and best case -- same
 * order as plain binary search, since we still discard half the remaining
 * range at each step.
 * Space complexity: O(1) extra space -- iterative, with only a few index
 * variables.
 */
public class BinarySearchRotatedArray {

    public static int search(int[] rotatedSortedArr, int target) {
        int low = 0;
        int high = rotatedSortedArr.length - 1;

        while (low <= high) {
            int mid = low + (high - low) / 2;

            if (rotatedSortedArr[mid] == target) {
                return mid;
            }

            if (rotatedSortedArr[low] <= rotatedSortedArr[mid]) {
                // Left half [low, mid] is sorted normally.
                if (target >= rotatedSortedArr[low] && target < rotatedSortedArr[mid]) {
                    high = mid - 1; // target must be in the sorted left half
                } else {
                    low = mid + 1; // target must be in the other half
                }
            } else {
                // Right half [mid, high] is sorted normally instead.
                if (target > rotatedSortedArr[mid] && target <= rotatedSortedArr[high]) {
                    low = mid + 1; // target must be in the sorted right half
                } else {
                    high = mid - 1; // target must be in the other half
                }
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        int[] data = {4, 5, 6, 7, 0, 1, 2};
        int target = 0;
        System.out.println("Rotated sorted array: " + Arrays.toString(data));
        int result = search(data, target);
        if (result != -1) {
            System.out.println("Found " + target + " at index " + result);
        } else {
            System.out.println(target + " not found in array");
        }
    }
}
