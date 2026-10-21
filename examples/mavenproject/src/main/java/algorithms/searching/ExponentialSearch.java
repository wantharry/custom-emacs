import java.util.Arrays;

/**
 * Exponential Search (a.k.a. Doubling Search)
 *
 * What it does: finds the index of a target value in a sorted array of
 * integers, particularly well-suited for unbounded or very large sorted
 * arrays where we don't want to even look at the array's full length up
 * front.
 *
 * Core idea: start with a small range and keep doubling its upper bound
 * (1, 2, 4, 8, 16, ...) until either we run off the end of the array or we
 * find a bound whose value is >= the target. This quickly brackets the
 * target between the previous bound and the current one. Once that range
 * is found, run ordinary binary search restricted to just that bracket.
 * The doubling phase finds the right "ballpark" in logarithmic time, and
 * then binary search narrows it down from there -- effectively binary
 * search with a smarter way of finding the initial range instead of
 * assuming the whole array as the range from the start.
 *
 * Time complexity: O(log i) where i is the index of the target (or array
 * length if absent) -- the doubling phase takes O(log i) steps, and the
 * subsequent binary search over a range of size O(i) also takes O(log i).
 * Space complexity: O(1) extra space for the iterative doubling phase and
 * iterative binary search used here.
 */
public class ExponentialSearch {

    public static int search(int[] sortedArr, int target) {
        int n = sortedArr.length;
        if (n == 0) {
            return -1;
        }
        if (sortedArr[0] == target) {
            return 0;
        }

        // Double the bound until it either exceeds array length or its value >= target.
        int bound = 1;
        while (bound < n && sortedArr[bound] < target) {
            bound *= 2;
        }

        // Binary search within the bracket [bound/2, min(bound, n-1)].
        int low = bound / 2;
        int high = Math.min(bound, n - 1);
        return binarySearch(sortedArr, target, low, high);
    }

    private static int binarySearch(int[] arr, int target, int low, int high) {
        while (low <= high) {
            int mid = low + (high - low) / 2;
            if (arr[mid] == target) {
                return mid;
            } else if (arr[mid] < target) {
                low = mid + 1;
            } else {
                high = mid - 1;
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        int[] data = {1, 3, 6, 9, 14, 21, 29, 38, 48, 59, 71, 84};
        int target = 48;
        System.out.println("Sorted array: " + Arrays.toString(data));
        int result = search(data, target);
        if (result != -1) {
            System.out.println("Found " + target + " at index " + result);
        } else {
            System.out.println(target + " not found in array");
        }
    }
}
