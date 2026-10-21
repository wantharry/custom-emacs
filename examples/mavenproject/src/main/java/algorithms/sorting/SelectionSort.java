import java.util.Arrays;

/**
 * Selection Sort
 *
 * What it does: sorts an array of integers into ascending order by
 * repeatedly selecting the smallest remaining element and placing it at the
 * front of the unsorted portion.
 *
 * Core idea: the array is conceptually split into a sorted prefix (initially
 * empty) and an unsorted suffix (initially the whole array). On each pass,
 * scan the entire unsorted suffix to find its minimum element, then swap
 * that minimum into the first position of the suffix, which grows the sorted
 * prefix by one element. Repeat until the unsorted suffix is empty. Unlike
 * bubble sort, selection sort does at most one swap per pass -- the cost is
 * all in the scanning/comparisons, not the swapping.
 *
 * Time complexity: O(n^2) in all cases (best, average, worst) because the
 * algorithm always scans the full remaining unsorted suffix to find the
 * minimum, regardless of input order.
 * Space complexity: O(1) extra space -- sorting happens in place with only a
 * few scalar variables.
 */
public class SelectionSort {

    public static void sort(int[] arr) {
        int n = arr.length;
        for (int i = 0; i < n - 1; i++) {
            int minIndex = i;
            // Find the index of the smallest element in the unsorted suffix [i, n).
            for (int j = i + 1; j < n; j++) {
                if (arr[j] < arr[minIndex]) {
                    minIndex = j;
                }
            }
            // Place that smallest element at the front of the unsorted suffix.
            if (minIndex != i) {
                int temp = arr[i];
                arr[i] = arr[minIndex];
                arr[minIndex] = temp;
            }
        }
    }

    public static void main(String[] args) {
        int[] data = {64, 25, 12, 22, 11};
        System.out.println("Original: " + Arrays.toString(data));
        sort(data);
        System.out.println("Sorted:   " + Arrays.toString(data));
    }
}
