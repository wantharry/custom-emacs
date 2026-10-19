import java.util.Arrays;

/**
 * Merge Sort
 *
 * What it does: sorts an array of integers into ascending order using the
 * classic divide-and-conquer strategy.
 *
 * Core idea: recursively split the array in half until each piece has just
 * one element (a single element is trivially sorted). Then merge pairs of
 * sorted pieces back together: walk two sorted sub-arrays with two pointers,
 * repeatedly taking the smaller of the two current elements into a new
 * output array, until both sub-arrays are exhausted. Merging two sorted
 * arrays this way is linear time, and because we halve the problem at every
 * level of recursion, the total work across all levels works out to
 * n * log(n).
 *
 * Time complexity: O(n log n) in the best, average, and worst case -- the
 * split/merge structure is independent of the input's initial order.
 * Space complexity: O(n) extra space for the temporary arrays used during
 * merging (plus O(log n) recursion stack space).
 */
public class MergeSort {

    public static void sort(int[] arr) {
        if (arr.length < 2) {
            return;
        }
        mergeSort(arr, 0, arr.length - 1);
    }

    private static void mergeSort(int[] arr, int left, int right) {
        if (left >= right) {
            return;
        }
        int mid = left + (right - left) / 2;
        mergeSort(arr, left, mid);
        mergeSort(arr, mid + 1, right);
        merge(arr, left, mid, right);
    }

    private static void merge(int[] arr, int left, int mid, int right) {
        int[] leftArr = Arrays.copyOfRange(arr, left, mid + 1);
        int[] rightArr = Arrays.copyOfRange(arr, mid + 1, right + 1);

        int i = 0, j = 0, k = left;
        // Take the smaller of the two fronts each time.
        while (i < leftArr.length && j < rightArr.length) {
            if (leftArr[i] <= rightArr[j]) {
                arr[k++] = leftArr[i++];
            } else {
                arr[k++] = rightArr[j++];
            }
        }
        // Copy over whichever sub-array still has leftovers.
        while (i < leftArr.length) {
            arr[k++] = leftArr[i++];
        }
        while (j < rightArr.length) {
            arr[k++] = rightArr[j++];
        }
    }

    public static void main(String[] args) {
        int[] data = {38, 27, 43, 3, 9, 82, 10};
        System.out.println("Original: " + Arrays.toString(data));
        sort(data);
        System.out.println("Sorted:   " + Arrays.toString(data));
    }
}
