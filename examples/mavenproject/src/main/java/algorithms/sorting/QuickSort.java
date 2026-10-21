import java.util.Arrays;

/**
 * Quick Sort
 *
 * What it does: sorts an array of integers into ascending order using
 * divide-and-conquer with in-place partitioning.
 *
 * Core idea: pick an element from the array as the "pivot" (here, the last
 * element of the current sub-range). Partition the sub-range so that every
 * element smaller than the pivot ends up to its left and every element
 * greater ends up to its right, with the pivot dropped in between them at
 * its final sorted position. Then recursively apply the same process to the
 * left part and the right part independently. Because the pivot never needs
 * to move again after partitioning, and partitioning is done in place with a
 * single pass, this tends to be very fast in practice despite the
 * quadratic worst case.
 *
 * Time complexity: O(n log n) on average (balanced partitions), but O(n^2)
 * in the worst case, which happens when partitioning is maximally
 * unbalanced, e.g. already-sorted input with a naive last-element pivot
 * choice.
 * Space complexity: O(log n) on average for the recursion call stack (O(n)
 * in the worst case of unbalanced recursion); sorting itself is done in
 * place with O(1) extra array space.
 */
public class QuickSort {

    public static void sort(int[] arr) {
        if (arr.length < 2) {
            return;
        }
        quickSort(arr, 0, arr.length - 1);
    }

    private static void quickSort(int[] arr, int low, int high) {
        if (low < high) {
            int pivotIndex = partition(arr, low, high);
            quickSort(arr, low, pivotIndex - 1);
            quickSort(arr, pivotIndex + 1, high);
        }
    }

    private static int partition(int[] arr, int low, int high) {
        int pivot = arr[high];
        int i = low - 1; // boundary of elements known to be <= pivot
        for (int j = low; j < high; j++) {
            if (arr[j] <= pivot) {
                i++;
                swap(arr, i, j);
            }
        }
        // Place the pivot right after the last element known to be <= pivot.
        swap(arr, i + 1, high);
        return i + 1;
    }

    private static void swap(int[] arr, int a, int b) {
        int temp = arr[a];
        arr[a] = arr[b];
        arr[b] = temp;
    }

    public static void main(String[] args) {
        int[] data = {10, 7, 8, 9, 1, 5};
        System.out.println("Original: " + Arrays.toString(data));
        sort(data);
        System.out.println("Sorted:   " + Arrays.toString(data));
    }
}
