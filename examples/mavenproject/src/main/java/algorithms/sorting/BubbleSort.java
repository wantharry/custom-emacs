import java.util.Arrays;

/**
 * Bubble Sort
 *
 * What it does: sorts an array of integers into ascending order by repeatedly
 * walking through the array and swapping adjacent elements that are out of
 * order.
 *
 * Core idea: on each pass, compare every pair of neighboring elements. If the
 * left one is bigger than the right one, swap them. After one full pass, the
 * largest unsorted element has "bubbled up" to its correct position at the
 * end of the array (like a bubble rising to the surface). Repeat the pass,
 * each time over a slightly shorter unsorted prefix, until a full pass makes
 * no swaps at all -- that means the array is fully sorted and we can stop
 * early.
 *
 * Time complexity: O(n^2) in the average and worst case (nested loops over
 * the array), but O(n) in the best case (already sorted input) thanks to the
 * early-exit flag.
 * Space complexity: O(1) extra space -- it sorts in place, only swapping
 * elements within the original array.
 */
public class BubbleSort {

    public static void sort(int[] arr) {
        int n = arr.length;
        for (int i = 0; i < n - 1; i++) {
            boolean swapped = false;
            // After i passes, the last i elements are already the largest and in place.
            for (int j = 0; j < n - 1 - i; j++) {
                if (arr[j] > arr[j + 1]) {
                    int temp = arr[j];
                    arr[j] = arr[j + 1];
                    arr[j + 1] = temp;
                    swapped = true;
                }
            }
            // If nothing was swapped in this pass, the array is already sorted.
            if (!swapped) {
                break;
            }
        }
    }

    public static void main(String[] args) {
        int[] data = {64, 34, 25, 12, 22, 11, 90};
        System.out.println("Original: " + Arrays.toString(data));
        sort(data);
        System.out.println("Sorted:   " + Arrays.toString(data));
    }
}
