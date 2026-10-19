import java.util.Arrays;

/**
 * Fibonacci Search
 *
 * What it does: finds the index of a target value in a sorted array of
 * integers using Fibonacci numbers to decide where to probe, instead of
 * plain division by two (as binary search does) or arithmetic on the
 * values themselves (as interpolation search does).
 *
 * Core idea: find the smallest Fibonacci number that is >= the array's
 * length; this Fibonacci number and its two preceding Fibonacci numbers
 * define how the search range will be split at each step, in a ratio
 * similar to the golden ratio rather than an even half. At each step, we
 * probe at an offset determined by the smaller of the two trailing
 * Fibonacci numbers. If the target is larger than the probed value, we
 * shift the window forward and reduce our Fibonacci numbers by two steps;
 * if smaller, we reduce by one step and keep the window's start. This
 * continues, with the Fibonacci numbers shrinking toward (1, 1, 0), until
 * the target is found or the search space is exhausted. Historically this
 * was attractive because it only needs addition and subtraction, not
 * division, which mattered on hardware where division was expensive.
 *
 * Time complexity: O(log n) in the worst case, the same asymptotic order
 * as binary search, since Fibonacci numbers grow exponentially.
 * Space complexity: O(1) extra space -- a handful of scalar variables for
 * the Fibonacci numbers and the current offset.
 */
public class FibonacciSearch {

    public static int search(int[] sortedArr, int target) {
        int n = sortedArr.length;
        if (n == 0) {
            return -1;
        }

        // Find the smallest Fibonacci number >= n, tracking the two before it.
        int fibM2 = 0; // (m-2)'th Fibonacci number
        int fibM1 = 1; // (m-1)'th Fibonacci number
        int fibM = fibM2 + fibM1; // m'th Fibonacci number
        while (fibM < n) {
            fibM2 = fibM1;
            fibM1 = fibM;
            fibM = fibM2 + fibM1;
        }

        int offset = -1; // marks the eliminated range from the front

        while (fibM > 1) {
            // Candidate index to compare, bounded by the array length.
            int i = Math.min(offset + fibM2, n - 1);

            if (sortedArr[i] < target) {
                // Target is in the subarray after i; shrink to the "two back" Fibonacci pair.
                fibM = fibM1;
                fibM1 = fibM2;
                fibM2 = fibM - fibM1;
                offset = i;
            } else if (sortedArr[i] > target) {
                // Target is in the subarray before i; shrink to the "one back" Fibonacci pair.
                fibM = fibM2;
                fibM1 = fibM1 - fibM2;
                fibM2 = fibM - fibM1;
            } else {
                return i;
            }
        }

        // At most one element might remain to check.
        if (fibM1 == 1 && offset + 1 < n && sortedArr[offset + 1] == target) {
            return offset + 1;
        }
        return -1;
    }

    public static void main(String[] args) {
        int[] data = {10, 22, 35, 40, 45, 50, 80, 82, 85, 90, 100};
        int target = 85;
        System.out.println("Sorted array: " + Arrays.toString(data));
        int result = search(data, target);
        if (result != -1) {
            System.out.println("Found " + target + " at index " + result);
        } else {
            System.out.println(target + " not found in array");
        }
    }
}
