import java.util.Arrays;

/**
 * Heap Sort
 *
 * What it does: sorts an array of integers into ascending order by first
 * turning the array into a max-heap, then repeatedly extracting the
 * maximum element.
 *
 * Core idea: a binary max-heap stored in an array has the property that
 * every parent node is >= both of its children, which means the maximum
 * element is always at index 0. First, "heapify" the whole array bottom-up
 * so it satisfies the max-heap property. Then repeatedly swap the root
 * (the current maximum) with the last unsorted element, shrink the heap's
 * logical size by one, and "sift down" the new root to restore the
 * max-heap property. Doing this n times, one maximum extraction at a time,
 * produces the fully sorted array, with the heap living in the same array
 * that gets sorted.
 *
 * Time complexity: O(n log n) in the best, average, and worst case --
 * building the heap is O(n), and each of the n extractions costs O(log n)
 * to sift down.
 * Space complexity: O(1) extra space -- the heap is built in place within
 * the original array, with only a constant number of scalar variables used.
 */
public class HeapSort {

    public static void sort(int[] arr) {
        int n = arr.length;

        // Build a max-heap: start from the last parent node and sift down.
        for (int i = n / 2 - 1; i >= 0; i--) {
            siftDown(arr, n, i);
        }

        // Repeatedly move the current max (the root) to the end of the array.
        for (int end = n - 1; end > 0; end--) {
            swap(arr, 0, end);
            siftDown(arr, end, 0); // restore heap property on the shrunk heap
        }
    }

    private static void siftDown(int[] arr, int heapSize, int root) {
        int largest = root;
        int left = 2 * root + 1;
        int right = 2 * root + 2;

        if (left < heapSize && arr[left] > arr[largest]) {
            largest = left;
        }
        if (right < heapSize && arr[right] > arr[largest]) {
            largest = right;
        }
        if (largest != root) {
            swap(arr, root, largest);
            siftDown(arr, heapSize, largest); // keep sifting down the displaced value
        }
    }

    private static void swap(int[] arr, int a, int b) {
        int temp = arr[a];
        arr[a] = arr[b];
        arr[b] = temp;
    }

    public static void main(String[] args) {
        int[] data = {12, 11, 13, 5, 6, 7};
        System.out.println("Original: " + Arrays.toString(data));
        sort(data);
        System.out.println("Sorted:   " + Arrays.toString(data));
    }
}
