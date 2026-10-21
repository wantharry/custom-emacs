import java.util.Arrays;

/**
 * Cocktail Sort (a.k.a. Cocktail Shaker Sort, Bidirectional Bubble Sort)
 *
 * What it does: sorts an array of integers into ascending order using a
 * two-directional variant of bubble sort.
 *
 * Core idea: plain bubble sort only ever sweeps left to right, so on each
 * pass only the single largest remaining element is guaranteed to reach its
 * final position (at the end); a small value stuck near the end only
 * crawls one step closer to the front per pass. Cocktail sort fixes this
 * "turtle" problem by alternating sweep direction: one pass left-to-right
 * bubbles the largest remaining value to the top of the unsorted range,
 * then a pass right-to-left bubbles the smallest remaining value to the
 * bottom of the unsorted range. Each full forward+backward pass shrinks the
 * unsorted range from both ends at once. The algorithm stops as soon as a
 * full back-and-forth pass makes no swaps, meaning the array is sorted.
 *
 * Time complexity: O(n^2) in the average and worst case, same order as
 * bubble sort, but O(n) in the best case (already sorted input); in
 * practice it tends to need fewer passes than plain bubble sort on data
 * with small values stuck near the end.
 * Space complexity: O(1) extra space -- sorts in place.
 */
public class CocktailSort {

    public static void sort(int[] arr) {
        int left = 0;
        int right = arr.length - 1;

        while (left < right) {
            boolean swapped = false;

            // Forward pass: bubble the largest remaining element to the right end.
            for (int i = left; i < right; i++) {
                if (arr[i] > arr[i + 1]) {
                    swap(arr, i, i + 1);
                    swapped = true;
                }
            }
            right--;

            // Backward pass: bubble the smallest remaining element to the left end.
            for (int i = right; i > left; i--) {
                if (arr[i - 1] > arr[i]) {
                    swap(arr, i - 1, i);
                    swapped = true;
                }
            }
            left++;

            if (!swapped) {
                break; // a full forward+backward sweep made no swaps: already sorted
            }
        }
    }

    private static void swap(int[] arr, int a, int b) {
        int temp = arr[a];
        arr[a] = arr[b];
        arr[b] = temp;
    }

    public static void main(String[] args) {
        int[] data = {5, 1, 4, 2, 8, 0, 2, 9};
        System.out.println("Original: " + Arrays.toString(data));
        sort(data);
        System.out.println("Sorted:   " + Arrays.toString(data));
    }
}
