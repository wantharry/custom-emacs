import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

/**
 * Bucket Sort
 *
 * What it does: sorts an array of integers into ascending order by
 * distributing elements into a number of "buckets" covering sub-ranges of
 * the input's value range, sorting each bucket individually, and then
 * concatenating the buckets in order.
 *
 * Core idea: divide the range [min, max] of the input into a fixed number
 * of equal-width buckets. Scan the array once, dropping each element into
 * the bucket that covers its value. Because each bucket now only holds
 * values from a narrow sub-range, sorting each bucket individually with a
 * simple algorithm (insertion sort here, since buckets are expected to be
 * small) is cheap. Finally, concatenate the sorted buckets in order from
 * lowest range to highest -- since every value in an earlier bucket is <=
 * every value in a later bucket by construction, the concatenation is
 * already globally sorted. This performs best when the input is
 * reasonably uniformly distributed across its range, so each bucket ends
 * up with roughly the same small number of elements.
 *
 * Time complexity: O(n + k) on average when elements are uniformly
 * distributed across k buckets (each bucket gets O(n/k) elements, so
 * insertion-sorting all buckets costs O(n) total); O(n^2) in the worst case
 * if all elements land in a single bucket.
 * Space complexity: O(n + k) for the buckets and their contents.
 */
public class BucketSort {

    public static void sort(int[] arr) {
        if (arr.length < 2) {
            return;
        }

        int max = arr[0], min = arr[0];
        for (int value : arr) {
            if (value > max) max = value;
            if (value < min) min = value;
        }

        int bucketCount = arr.length; // one bucket per element, on average
        List<List<Integer>> buckets = new ArrayList<>();
        for (int i = 0; i < bucketCount; i++) {
            buckets.add(new ArrayList<>());
        }

        int range = max - min + 1;
        // Distribute each element into the bucket covering its value.
        for (int value : arr) {
            int bucketIndex = (int) ((long) (value - min) * bucketCount / range);
            if (bucketIndex >= bucketCount) {
                bucketIndex = bucketCount - 1;
            }
            buckets.get(bucketIndex).add(value);
        }

        int index = 0;
        // Sort each bucket individually, then lay them back into the array in order.
        for (List<Integer> bucket : buckets) {
            Collections.sort(bucket);
            for (int value : bucket) {
                arr[index++] = value;
            }
        }
    }

    public static void main(String[] args) {
        int[] data = {29, 25, 3, 49, 9, 37, 21, 43};
        System.out.println("Original: " + Arrays.toString(data));
        sort(data);
        System.out.println("Sorted:   " + Arrays.toString(data));
    }
}
