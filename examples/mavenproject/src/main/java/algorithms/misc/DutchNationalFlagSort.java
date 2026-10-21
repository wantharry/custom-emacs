/**
 * DUTCH NATIONAL FLAG SORT (THREE-WAY PARTITIONING)
 * ---------------------------------------------------------
 * Given an array containing only three distinct values (classically 0s, 1s,
 * and 2s -- named after the three bands of the Dutch flag), sort it in a
 * single pass, in place, without using extra space for counting or a
 * general-purpose sort.
 *
 * Core idea: maintain three pointers that partition the array into four
 * conceptual regions as we scan: [0 .. low-1] is all 0s, [low .. mid-1] is
 * all 1s, [mid .. high] is unprocessed/unknown, and [high+1 .. end] is all
 * 2s. We look at array[mid] (the next unprocessed element): if it's 0, we
 * swap it into the 0-region at "low" and advance both low and mid (the
 * swapped-in element at mid is now known to be 1, from the invariant, so
 * it's safe to also advance mid); if it's 1, it's already in the right
 * place, so we just advance mid; if it's 2, we swap it into the 2-region at
 * "high" and shrink high, but do NOT advance mid, because the element just
 * swapped into mid's position from the end hasn't been classified yet. This
 * invariant-preserving swap process sorts the whole array in one left-to-
 * right sweep.
 *
 * Complexity (n = array length):
 *   - Time: O(n) -- a single pass; mid advances every iteration except the
 *     "swap with high" case, and high only ever decreases, so the total work
 *     is bounded by n.
 *   - Space: O(1) extra space (sorted in place).
 */
public class DutchNationalFlagSort {

    public static void sort(int[] array) {
        int low = 0, mid = 0, high = array.length - 1;

        while (mid <= high) {
            if (array[mid] == 0) {
                swap(array, low, mid);
                low++;
                mid++;
            } else if (array[mid] == 1) {
                mid++;
            } else { // array[mid] == 2
                swap(array, mid, high);
                high--;
            }
        }
    }

    private static void swap(int[] array, int i, int j) {
        int t = array[i];
        array[i] = array[j];
        array[j] = t;
    }

    public static void main(String[] args) {
        int[] array = {2, 0, 1, 2, 1, 0, 0, 2, 1, 0};
        System.out.println("Before: " + java.util.Arrays.toString(array));
        sort(array);
        System.out.println("After:  " + java.util.Arrays.toString(array));

        int[] array2 = {1, 1, 1, 0, 0, 2};
        System.out.println("Before: " + java.util.Arrays.toString(array2));
        sort(array2);
        System.out.println("After:  " + java.util.Arrays.toString(array2));

        int[] array3 = {}; // edge case: empty array
        sort(array3);
        System.out.println("Empty array sorted without error: " + java.util.Arrays.toString(array3));
    }
}
