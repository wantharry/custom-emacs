import java.util.Arrays;

/**
 * Jump Search
 *
 * What it does: finds the index of a target value in a sorted array of
 * integers by jumping ahead in fixed-size blocks before doing a final
 * linear scan.
 *
 * Core idea: instead of checking every element (like linear search) or
 * halving the range every time (like binary search), jump search checks
 * one element every "step" positions (a good step size is sqrt(n)). As
 * soon as a jump lands on a value that is >= the target, we know the
 * target -- if present -- must lie in the block just before that jump
 * (since the array is sorted). We then fall back to a simple linear scan
 * within just that small block to pin down the exact index. This strikes a
 * balance between binary search's random-access jumps (not always cheap,
 * e.g. on certain storage media) and linear search's simplicity, by only
 * needing to move forward in blocks.
 *
 * Time complexity: O(sqrt(n)) in the worst and average case, achieved by
 * choosing a block/step size of sqrt(n): roughly sqrt(n) jumps plus a
 * linear scan of at most sqrt(n) elements within the final block.
 * Space complexity: O(1) extra space -- just a couple of index variables.
 */
public class JumpSearch {

    public static int search(int[] sortedArr, int target) {
        int n = sortedArr.length;
        if (n == 0) {
            return -1;
        }
        int step = (int) Math.sqrt(n);

        // Jump ahead in blocks until we find a block that could contain the target.
        int prev = 0;
        int current = step;
        while (current < n && sortedArr[current - 1] < target) {
            prev = current;
            current += step;
        }

        // Linear scan within the identified block [prev, min(current, n)).
        int limit = Math.min(current, n);
        for (int i = prev; i < limit; i++) {
            if (sortedArr[i] == target) {
                return i;
            }
        }
        return -1;
    }

    public static void main(String[] args) {
        int[] data = {0, 1, 3, 4, 7, 9, 13, 18, 22, 27, 33, 40};
        int target = 22;
        System.out.println("Sorted array: " + Arrays.toString(data));
        int result = search(data, target);
        if (result != -1) {
            System.out.println("Found " + target + " at index " + result);
        } else {
            System.out.println(target + " not found in array");
        }
    }
}
