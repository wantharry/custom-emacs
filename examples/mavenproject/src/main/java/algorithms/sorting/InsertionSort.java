import java.util.Arrays;

/**
 * Insertion Sort
 *
 * What it does: sorts an array of integers into ascending order the way
 * many people sort a hand of playing cards -- by building up a sorted
 * section one element at a time and inserting each new element into its
 * correct place within that section.
 *
 * Core idea: treat the first element as a trivially sorted section of size
 * one. For each subsequent element ("the key"), shift it leftward past all
 * elements in the sorted section that are greater than it, opening a gap,
 * and then drop the key into that gap. After processing every element this
 * way, the whole array is sorted. It performs very well on nearly-sorted
 * data because few shifts are needed.
 *
 * Time complexity: O(n^2) in the average and worst case (reverse-sorted
 * input causes maximal shifting), but O(n) in the best case (already
 * sorted input, since the inner loop immediately stops).
 * Space complexity: O(1) extra space -- sorts in place, shifting elements
 * within the original array.
 */
public class InsertionSort {

    public static void sort(int[] arr) {
        int n = arr.length;
        for (int i = 1; i < n; i++) {
            int key = arr[i];
            int j = i - 1;
            // Shift every element greater than key one position to the right.
            while (j >= 0 && arr[j] > key) {
                arr[j + 1] = arr[j];
                j--;
            }
            // Drop key into the gap left behind.
            arr[j + 1] = key;
        }
    }

    public static void main(String[] args) {
        int[] data = {12, 11, 13, 5, 6};
        System.out.println("Original: " + Arrays.toString(data));
        sort(data);
        System.out.println("Sorted:   " + Arrays.toString(data));
    }
}
