import java.util.Arrays;

/**
 * Counting Sort
 *
 * What it does: sorts an array of non-negative integers into ascending
 * order without doing any element-to-element comparisons.
 *
 * Core idea: instead of comparing elements, count how many times each
 * distinct value occurs. Build a "count" array indexed by value, where
 * count[v] holds how many times v appears in the input. Then convert those
 * counts into a prefix-sum (running total), so count[v] now tells us the
 * index just past where the last occurrence of v should land in the sorted
 * output. Walk the original array from right to left, placing each element
 * into the output at the position given by its running count, and
 * decrementing that count -- this keeps the sort stable (equal elements
 * keep their original relative order). This only works efficiently when the
 * range of possible values (k) is not too much larger than n, since we
 * allocate an array of that size.
 *
 * Time complexity: O(n + k), where n is the number of elements and k is the
 * range of input values (max - min + 1). This is better than any
 * comparison-based sort's O(n log n) lower bound, but only when k is O(n).
 * Space complexity: O(n + k) for the output array and the counting array.
 */
public class CountingSort {

    public static int[] sort(int[] arr) {
        if (arr.length == 0) {
            return arr;
        }

        int max = arr[0], min = arr[0];
        for (int value : arr) {
            if (value > max) max = value;
            if (value < min) min = value;
        }

        int range = max - min + 1;
        int[] count = new int[range];
        for (int value : arr) {
            count[value - min]++;
        }

        // Turn counts into prefix sums: count[i] becomes the index just past
        // the last place a value of (i + min) should be written.
        for (int i = 1; i < range; i++) {
            count[i] += count[i - 1];
        }

        int[] output = new int[arr.length];
        // Iterate right to left so equal elements keep their relative order (stability).
        for (int i = arr.length - 1; i >= 0; i--) {
            int value = arr[i];
            count[value - min]--;
            output[count[value - min]] = value;
        }
        return output;
    }

    public static void main(String[] args) {
        int[] data = {4, 2, 2, 8, 3, 3, 1};
        System.out.println("Original: " + Arrays.toString(data));
        int[] sorted = sort(data);
        System.out.println("Sorted:   " + Arrays.toString(sorted));
    }
}
