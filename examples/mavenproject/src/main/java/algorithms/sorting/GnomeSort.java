import java.util.Arrays;

/**
 * Gnome Sort (a.k.a. Stupid Sort)
 *
 * What it does: sorts an array of integers into ascending order using a
 * single wandering pointer that moves forward when things are in order and
 * steps backward to fix things when they are not -- like a garden gnome
 * sorting flower pots by picking up a pot, and if it's smaller than the one
 * before it, swapping back repeatedly until it's in place, then continuing
 * forward.
 *
 * Core idea: keep one position pointer. If the element at the pointer is
 * greater than or equal to the element before it, the local order is fine,
 * so step the pointer forward. Otherwise, swap the two elements and step
 * the pointer backward (unless it's already at the start) to re-check the
 * new, smaller element against whatever now precedes it. This is logically
 * equivalent to a very simple form of insertion sort, but implemented with
 * one index and no explicit nested loop or shifting -- just forward and
 * backward single-steps. The pointer only reaches the end once every
 * element has settled into a position where it's >= its predecessor.
 *
 * Time complexity: O(n^2) in the average and worst case (lots of
 * backward steps needed for very unsorted input), but O(n) in the best
 * case (already sorted input, since the pointer only ever moves forward).
 * Space complexity: O(1) extra space -- sorts in place with a single index
 * variable.
 */
public class GnomeSort {

    public static void sort(int[] arr) {
        int n = arr.length;
        int index = 0;

        while (index < n) {
            if (index == 0 || arr[index] >= arr[index - 1]) {
                index++; // in order here, move forward
            } else {
                swap(arr, index, index - 1);
                index--; // step back to re-check the swapped element
            }
        }
    }

    private static void swap(int[] arr, int a, int b) {
        int temp = arr[a];
        arr[a] = arr[b];
        arr[b] = temp;
    }

    public static void main(String[] args) {
        int[] data = {34, 2, 10, -9, 7, 1, 0};
        System.out.println("Original: " + Arrays.toString(data));
        sort(data);
        System.out.println("Sorted:   " + Arrays.toString(data));
    }
}
