import java.util.Arrays;

/**
 * Radix Sort (LSD, base 10)
 *
 * What it does: sorts an array of non-negative integers into ascending
 * order by processing their decimal digits instead of comparing whole
 * values against each other.
 *
 * Core idea: this is "least significant digit" (LSD) radix sort. Starting
 * from the ones digit and moving toward more significant digits, repeatedly
 * bucket every number by its current digit (0-9) and reassemble the array
 * in bucket order, using a stable sorting pass (counting sort) for each
 * digit. Because counting sort is stable, numbers that tie on the current
 * digit keep the relative order they had from sorting on the previous,
 * less significant digit. After processing every digit up to the number of
 * digits in the largest value, the array ends up fully sorted -- sorting by
 * the ones digit first, then tens, then hundreds, and so on, each pass
 * refines the ordering established by the pass before it.
 *
 * Time complexity: O(d * (n + b)), where n is the number of elements, b is
 * the base (10 here, so the per-digit counting sort is O(n + 10)), and d is
 * the number of digits in the largest number. For fixed-width integers this
 * is effectively O(n).
 * Space complexity: O(n + b) for the output array and per-digit counting
 * array used on each pass.
 */
public class RadixSort {

    public static void sort(int[] arr) {
        if (arr.length == 0) {
            return;
        }
        int max = Arrays.stream(arr).max().getAsInt();

        // Run a stable counting sort on each digit, from least to most significant.
        for (int digitPlace = 1; max / digitPlace > 0; digitPlace *= 10) {
            countingSortByDigit(arr, digitPlace);
        }
    }

    private static void countingSortByDigit(int[] arr, int digitPlace) {
        int n = arr.length;
        int[] output = new int[n];
        int[] count = new int[10]; // digits 0-9

        for (int value : arr) {
            int digit = (value / digitPlace) % 10;
            count[digit]++;
        }
        for (int i = 1; i < 10; i++) {
            count[i] += count[i - 1];
        }
        // Iterate right to left to keep the sort stable for this digit.
        for (int i = n - 1; i >= 0; i--) {
            int digit = (arr[i] / digitPlace) % 10;
            count[digit]--;
            output[count[digit]] = arr[i];
        }
        System.arraycopy(output, 0, arr, 0, n);
    }

    public static void main(String[] args) {
        int[] data = {170, 45, 75, 90, 802, 24, 2, 66};
        System.out.println("Original: " + Arrays.toString(data));
        sort(data);
        System.out.println("Sorted:   " + Arrays.toString(data));
    }
}
