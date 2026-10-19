/**
 * MAXIMUM PRODUCT SUBARRAY (DYNAMIC PROGRAMMING, O(1) SPACE)
 * ------------------------------------------------------------------
 * Given an array of integers (which may include negative numbers and
 * zeros), find the contiguous subarray that has the largest product, and
 * return that product. Negative numbers make this trickier than the
 * analogous "maximum sum subarray" problem, because multiplying by a
 * negative number flips the sign: the smallest (most negative) running
 * product can become the largest product if multiplied by another negative
 * number.
 *
 * Core idea: we scan once, left to right, tracking two running values ending
 * at the current position: the maximum product so far (maxEndingHere) and
 * the minimum product so far (minEndingHere). At each new element, three
 * candidates are possible for the new running max/min: the element alone
 * (restarting the subarray, useful right after a zero), the old max times
 * the element, and the old min times the element (this last one is the key
 * trick -- if the element is negative, multiplying the previous minimum
 * [most negative] by it can produce a new large positive maximum). We take
 * the max of the three candidates for the new max, and the min of the three
 * for the new min, then update the overall best answer seen so far. A zero
 * naturally resets both running values toward the "element alone" case,
 * which handles the array-splitting effect of zeros correctly.
 *
 * Complexity (n = array length):
 *   - Time: O(n) -- a single pass over the array.
 *   - Space: O(1) extra space (just a few running variables).
 */
public class MaxProductSubarray {

    public static long maxProduct(int[] array) {
        if (array.length == 0) throw new IllegalArgumentException("Array must be non-empty");

        long maxEndingHere = array[0];
        long minEndingHere = array[0];
        long best = array[0];

        for (int i = 1; i < array.length; i++) {
            long value = array[i];
            long candidate1 = value;
            long candidate2 = maxEndingHere * value;
            long candidate3 = minEndingHere * value;

            long newMax = Math.max(candidate1, Math.max(candidate2, candidate3));
            long newMin = Math.min(candidate1, Math.min(candidate2, candidate3));

            maxEndingHere = newMax;
            minEndingHere = newMin;
            best = Math.max(best, maxEndingHere);
        }
        return best;
    }

    public static void main(String[] args) {
        int[] array1 = {2, 3, -2, 4};
        System.out.println("Array: " + java.util.Arrays.toString(array1));
        System.out.println("Max product subarray: " + maxProduct(array1)); // 6, from [2,3]

        int[] array2 = {-2, 0, -1};
        System.out.println("Array: " + java.util.Arrays.toString(array2));
        System.out.println("Max product subarray: " + maxProduct(array2)); // 0

        int[] array3 = {-2, 3, -4};
        System.out.println("Array: " + java.util.Arrays.toString(array3));
        System.out.println("Max product subarray: " + maxProduct(array3)); // 24, from the whole array

        int[] array4 = {-1, -3, -10, 0, 60};
        System.out.println("Array: " + java.util.Arrays.toString(array4));
        System.out.println("Max product subarray: " + maxProduct(array4)); // 60
    }
}
