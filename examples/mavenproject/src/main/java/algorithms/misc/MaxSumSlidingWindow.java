/**
 * MAXIMUM SUM SUBARRAY OF FIXED SIZE K (SLIDING WINDOW)
 * -------------------------------------------------------------
 * Given an array and a fixed window size k, find the maximum sum achievable
 * by any k consecutive elements. The naive approach recomputes the sum of
 * each window from scratch (O(n*k)); the sliding window technique reuses
 * most of the previous window's sum instead.
 *
 * Core idea: compute the sum of the first k elements directly, once. Then
 * slide the window one position at a time: to go from the window ending at
 * index i to the window ending at index i+1, we simply subtract the element
 * that just left the window (the one at the window's old left edge) and add
 * the element that just entered it (the new right edge). This reuses almost
 * all of the previous computation instead of resumming k elements every
 * time, turning what looks like a nested-loop problem into a single linear
 * pass with O(1) work per step.
 *
 * Complexity (n = array length, k = window size):
 *   - Time: O(n) -- one pass to build the initial window sum, one more pass
 *     (n - k steps) to slide it across the rest of the array.
 *   - Space: O(1) extra space.
 */
public class MaxSumSlidingWindow {

    public static int maxSumFixedWindow(int[] array, int k) {
        if (array.length < k || k <= 0) {
            throw new IllegalArgumentException("Invalid window size for this array");
        }

        int windowSum = 0;
        for (int i = 0; i < k; i++) {
            windowSum += array[i];
        }

        int maxSum = windowSum;
        for (int i = k; i < array.length; i++) {
            windowSum += array[i] - array[i - k]; // slide: add new, remove old
            maxSum = Math.max(maxSum, windowSum);
        }
        return maxSum;
    }

    public static void main(String[] args) {
        int[] array = {2, 1, 5, 1, 3, 2, 4, 1};

        int k1 = 3;
        System.out.println("Array: " + java.util.Arrays.toString(array));
        System.out.println("Max sum of any " + k1 + " consecutive elements: " + maxSumFixedWindow(array, k1));

        int k2 = 2;
        System.out.println("Max sum of any " + k2 + " consecutive elements: " + maxSumFixedWindow(array, k2));

        int k3 = 5;
        System.out.println("Max sum of any " + k3 + " consecutive elements: " + maxSumFixedWindow(array, k3));
    }
}
