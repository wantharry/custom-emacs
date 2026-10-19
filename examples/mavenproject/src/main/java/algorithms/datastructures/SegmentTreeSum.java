/**
 * SEGMENT TREE (RANGE SUM, POINT UPDATE)
 * -----------------------------------------
 * A segment tree answers range queries (here: "sum of elements from index l to
 * r") and supports point updates, both faster than the naive O(n) per query
 * or O(n) rebuild per update. It is a binary tree built over the array where
 * each leaf represents a single array element and each internal node
 * represents the sum of its two children's ranges -- so the root represents
 * the sum of the whole array, and any node represents the sum of a contiguous
 * sub-range.
 *
 * Core idea: build() recursively splits [lo, hi] into [lo, mid] and
 * [mid+1, hi], builds each half, and stores the sum of the two children at the
 * parent -- O(n) nodes total, built bottom-up via recursion. update(i, v)
 * walks down to the leaf for index i, changes it, and on the way back up
 * recomputes every ancestor's sum from its two children. query(l, r) walks the
 * tree and combines contributions: if a node's range is fully inside [l, r] it
 * returns that node's precomputed sum immediately (no need to go deeper);
 * if it's fully outside, it contributes 0; otherwise it recurses into both
 * children and adds their results. Because any range [l, r] touches at most
 * O(log n) "fully inside" nodes per level, both operations stay logarithmic.
 *
 * Complexity (n = number of elements):
 *   - build: O(n) time, O(n) space (tree array of size ~4n)
 *   - update: O(log n) time
 *   - query: O(log n) time
 *   - overall space: O(n)
 */
public class SegmentTreeSum {

    private final int n;
    private final long[] tree;
    private final int[] source;

    public SegmentTreeSum(int[] values) {
        this.n = values.length;
        this.source = values.clone();
        this.tree = new long[4 * Math.max(1, n)];
        if (n > 0) build(0, 0, n - 1);
    }

    private void build(int node, int lo, int hi) {
        if (lo == hi) {
            tree[node] = source[lo];
            return;
        }
        int mid = (lo + hi) / 2;
        build(2 * node + 1, lo, mid);
        build(2 * node + 2, mid + 1, hi);
        tree[node] = tree[2 * node + 1] + tree[2 * node + 2];
    }

    public void update(int index, int newValue) {
        updateRec(0, 0, n - 1, index, newValue);
    }

    private void updateRec(int node, int lo, int hi, int index, int newValue) {
        if (lo == hi) {
            tree[node] = newValue;
            source[index] = newValue;
            return;
        }
        int mid = (lo + hi) / 2;
        if (index <= mid) updateRec(2 * node + 1, lo, mid, index, newValue);
        else updateRec(2 * node + 2, mid + 1, hi, index, newValue);
        tree[node] = tree[2 * node + 1] + tree[2 * node + 2];
    }

    public long queryRange(int l, int r) {
        return queryRec(0, 0, n - 1, l, r);
    }

    private long queryRec(int node, int lo, int hi, int l, int r) {
        if (r < lo || hi < l) return 0L; // fully outside
        if (l <= lo && hi <= r) return tree[node]; // fully inside
        int mid = (lo + hi) / 2;
        return queryRec(2 * node + 1, lo, mid, l, r)
                + queryRec(2 * node + 2, mid + 1, hi, l, r);
    }

    public static void main(String[] args) {
        int[] values = {2, 4, 5, 7, 8, 9, 1, 3};
        SegmentTreeSum segTree = new SegmentTreeSum(values);

        System.out.println("sum[1..4]: " + segTree.queryRange(1, 4)); // 4+5+7+8=24
        System.out.println("sum[0..7]: " + segTree.queryRange(0, 7)); // whole array = 39

        segTree.update(3, 20); // was 7, now 20
        System.out.println("After update(3, 20):");
        System.out.println("sum[1..4]: " + segTree.queryRange(1, 4)); // 4+5+20+8=37
        System.out.println("sum[0..7]: " + segTree.queryRange(0, 7)); // 39-7+20=52
    }
}
