import java.util.Arrays;

/**
 * Interpolation Search
 *
 * What it does: finds the index of a target value in a sorted array of
 * integers, probing smarter positions than binary search's always-pick-
 * the-middle approach, by exploiting the actual values stored, not just
 * their order.
 *
 * Core idea: binary search always checks the midpoint of the current
 * range, regardless of the magnitudes involved. Interpolation search
 * instead estimates where the target is likely to be, the same way a
 * person flipping through a phone book guesses that "Smith" is near the
 * end, not the middle. It computes a probe position using linear
 * interpolation: pos = low + (target - arr[low]) * (high - low) /
 * (arr[high] - arr[low]). If the array's values are roughly uniformly
 * distributed, this probe lands very close to the target's real location,
 * letting the range shrink much faster than halving. As with binary
 * search, each probe that misses narrows the range to one side.
 *
 * Time complexity: O(log log n) on average for uniformly distributed data,
 * but O(n) in the worst case (e.g. values that are exponentially spaced,
 * which makes the interpolation estimate badly wrong).
 * Space complexity: O(1) extra space -- iterative, with only a few index
 * variables.
 */
public class InterpolationSearch {

    public static int search(int[] sortedArr, int target) {
        int low = 0;
        int high = sortedArr.length - 1;

        while (low <= high && target >= sortedArr[low] && target <= sortedArr[high]) {
            if (low == high) {
                return sortedArr[low] == target ? low : -1;
            }

            // Estimate the probe position proportionally to where target should fall.
            int pos = low + (int) (((long) (target - sortedArr[low]) * (high - low))
                    / (sortedArr[high] - sortedArr[low]));

            if (sortedArr[pos] == target) {
                return pos;
            } else if (sortedArr[pos] < target) {
                low = pos + 1;
            } else {
                high = pos - 1;
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        int[] data = {10, 20, 25, 35, 42, 50, 61, 70, 88, 95};
        int target = 61;
        System.out.println("Sorted array: " + Arrays.toString(data));
        int result = search(data, target);
        if (result != -1) {
            System.out.println("Found " + target + " at index " + result);
        } else {
            System.out.println(target + " not found in array");
        }
    }
}
