/**
 * TWO SUM ON A SORTED ARRAY (TWO-POINTER TECHNIQUE)
 * -------------------------------------------------------
 * Given an array already sorted in ascending order and a target value, find
 * a pair of indices whose values sum exactly to the target (if one exists).
 * Because the array is sorted, we don't need a hash set or nested loops --
 * we can use two pointers moving toward each other.
 *
 * Core idea: start one pointer ("left") at the beginning of the array and
 * another ("right") at the end. Compute their sum. If the sum equals the
 * target, we found our pair. If the sum is too small, the only way to
 * increase it is to move left forward (since the array is sorted, every
 * element to the right of left is >= the current left value), so we advance
 * left. If the sum is too large, we move right backward to decrease it. This
 * works because at every step we eliminate one index as impossible to pair
 * with any remaining candidate on the other side, due to the sorted order
 * guaranteeing monotonic sums as the pointers move -- so we never need to
 * reconsider a discarded pointer position.
 *
 * Complexity (n = array length):
 *   - Time: O(n) -- the two pointers together traverse the array at most
 *     once (left only moves right, right only moves left, and they meet in
 *     the middle at worst).
 *   - Space: O(1) extra space.
 */
public class TwoSumSortedTwoPointer {

    /** Returns the pair of indices {left, right} summing to target, or null if none exists. */
    public static int[] findPair(int[] sortedArray, int target) {
        int left = 0;
        int right = sortedArray.length - 1;

        while (left < right) {
            int sum = sortedArray[left] + sortedArray[right];
            if (sum == target) {
                return new int[]{left, right};
            } else if (sum < target) {
                left++;
            } else {
                right--;
            }
        }
        return null;
    }

    public static void main(String[] args) {
        int[] sortedArray = {1, 3, 4, 6, 8, 11, 15};

        int target1 = 10;
        int[] result1 = findPair(sortedArray, target1);
        report(sortedArray, target1, result1);

        int target2 = 19;
        int[] result2 = findPair(sortedArray, target2);
        report(sortedArray, target2, result2);

        int target3 = 100;
        int[] result3 = findPair(sortedArray, target3);
        report(sortedArray, target3, result3);
    }

    private static void report(int[] array, int target, int[] result) {
        if (result == null) {
            System.out.println("Target " + target + ": no pair found.");
        } else {
            System.out.println("Target " + target + ": indices " + result[0] + " and " + result[1]
                    + " -> values " + array[result[0]] + " + " + array[result[1]] + " = " + target);
        }
    }
}
