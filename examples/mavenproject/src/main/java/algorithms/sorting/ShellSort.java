import java.util.Arrays;

/**
 * Shell Sort
 *
 * What it does: sorts an array of integers into ascending order by
 * generalizing insertion sort to compare and move elements that are far
 * apart before narrowing down to comparing neighbors.
 *
 * Core idea: plain insertion sort only ever compares adjacent elements, so
 * moving a small value from near the end of the array to near the start
 * takes many single-step shifts. Shell sort fixes this by first sorting
 * the elements that are "gap" positions apart (e.g. every 4th element
 * forms one sub-sequence, insertion-sorted independently), using a large
 * gap. This quickly moves far-out-of-place elements much closer to their
 * final position. The gap is then shrunk (here, repeatedly halved) and the
 * process repeats with smaller and smaller gaps, until the gap is 1, at
 * which point it performs one final ordinary insertion sort pass -- but by
 * then the array is already "almost sorted," so that last pass is cheap.
 *
 * Time complexity: depends on the gap sequence; using the simple
 * halving sequence (n/2, n/4, ..., 1) used here gives roughly O(n^2) worst
 * case, but it performs much better than plain insertion sort in practice,
 * and better gap sequences (e.g. Hibbard's) can achieve O(n^(3/2)) or
 * better.
 * Space complexity: O(1) extra space -- sorting is done in place.
 */
public class ShellSort {

    public static void sort(int[] arr) {
        int n = arr.length;

        // Start with a large gap and shrink it each round.
        for (int gap = n / 2; gap > 0; gap /= 2) {
            // Insertion sort, but comparing/moving elements `gap` apart instead of adjacent ones.
            for (int i = gap; i < n; i++) {
                int key = arr[i];
                int j = i - gap;
                while (j >= 0 && arr[j] > key) {
                    arr[j + gap] = arr[j];
                    j -= gap;
                }
                arr[j + gap] = key;
            }
        }
    }

    public static void main(String[] args) {
        int[] data = {23, 29, 15, 19, 31, 7, 9, 5, 2};
        System.out.println("Original: " + Arrays.toString(data));
        sort(data);
        System.out.println("Sorted:   " + Arrays.toString(data));
    }
}
