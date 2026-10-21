/**
 * FENWICK TREE / BINARY INDEXED TREE (BIT) - PREFIX SUM, POINT UPDATE
 * -----------------------------------------------------------------------
 * A Fenwick tree answers prefix-sum queries ("sum of elements from index 1 to
 * i") and point updates in O(log n), using only a single array of size n+1
 * and clever bit manipulation -- no explicit tree nodes or pointers needed,
 * which makes it much lighter weight than a segment tree for this specific
 * job (prefix sums / range sums derived from them).
 *
 * Core idea: index i (1-based) in the BIT array is responsible for the sum of
 * a range of the original array whose length equals the value of i's lowest
 * set bit. To update index i, we add the delta to tree[i], then jump to the
 * next index that also covers i by adding i's lowest set bit:
 * i += (i & -i) -- repeating until past n. This visits every BIT node whose
 * range includes i. To query the prefix sum up to i, we add tree[i] and jump
 * backward by removing the lowest set bit: i -= (i & -i) -- repeating until
 * i reaches 0, which visits a chain of disjoint ranges that together cover
 * [1, i]. A range sum [l, r] is simply prefixSum(r) - prefixSum(l - 1).
 *
 * Complexity (n = number of elements):
 *   - build (n sequential updates): O(n log n) time
 *   - update(i, delta): O(log n) time
 *   - prefixSum(i) / rangeSum(l, r): O(log n) time
 *   - overall space: O(n)
 */
public class FenwickTreeBIT {

    private final int n;
    private final long[] tree; // 1-indexed

    public FenwickTreeBIT(int n) {
        this.n = n;
        this.tree = new long[n + 1];
    }

    public FenwickTreeBIT(int[] values) {
        this(values.length);
        for (int i = 0; i < values.length; i++) {
            update(i + 1, values[i]); // convert to 1-based index
        }
    }

    /** Adds delta to the element at 1-based index i. */
    public void update(int i, long delta) {
        for (; i <= n; i += i & (-i)) {
            tree[i] += delta;
        }
    }

    /** Sum of elements in [1, i] (1-based, inclusive). */
    public long prefixSum(int i) {
        long sum = 0;
        for (; i > 0; i -= i & (-i)) {
            sum += tree[i];
        }
        return sum;
    }

    /** Sum of elements in [l, r] (1-based, inclusive). */
    public long rangeSum(int l, int r) {
        if (l > 1) return prefixSum(r) - prefixSum(l - 1);
        return prefixSum(r);
    }

    public static void main(String[] args) {
        int[] values = {2, 4, 5, 7, 8, 9, 1, 3}; // 1-based positions 1..8
        FenwickTreeBIT bit = new FenwickTreeBIT(values);

        System.out.println("prefixSum(4) [elements 1..4]: " + bit.prefixSum(4)); // 2+4+5+7=18
        System.out.println("rangeSum(2, 5) [elements 2..5]: " + bit.rangeSum(2, 5)); // 4+5+7+8=24

        // Position 4 currently holds value 7; add 13 to make it 20.
        bit.update(4, 13);
        System.out.println("After update(4, +13):");
        System.out.println("prefixSum(4): " + bit.prefixSum(4)); // 2+4+5+20=31
        System.out.println("rangeSum(2, 5): " + bit.rangeSum(2, 5)); // 4+5+20+8=37
    }
}
