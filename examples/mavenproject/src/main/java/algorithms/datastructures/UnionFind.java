/**
 * UNION-FIND (DISJOINT SET UNION, WITH PATH COMPRESSION + UNION BY RANK)
 * --------------------------------------------------------------------------
 * Union-Find tracks a collection of elements partitioned into disjoint sets
 * (e.g. "which elements are connected to each other") and supports two
 * operations: union(a, b), merging the sets containing a and b, and find(a),
 * returning a representative ("root") identifying which set a belongs to. Two
 * elements are in the same set exactly when find(a) == find(b).
 *
 * Core idea: each element points to a "parent"; following parent pointers
 * repeatedly leads to a root (an element that is its own parent). find() does
 * that walk. Two optimizations keep this near-constant time:
 *   - Path compression: while walking up during find(), we re-point every
 *     visited node directly to the root we found, flattening the tree so
 *     future finds are faster.
 *   - Union by rank: when merging two sets, the root of the shallower tree
 *     (lower rank) is attached under the root of the deeper tree, which keeps
 *     trees from growing tall in the first place.
 * Together these two tricks give amortized near-O(1) operations instead of the
 * O(n) worst case a naive linked-parent chain would have.
 *
 * Complexity (n = number of elements):
 *   - find / union: O(alpha(n)) amortized time, which is effectively O(1) in
 *     practice (alpha is the inverse Ackermann function, grows extremely slowly)
 *   - overall space: O(n)
 */
public class UnionFind {

    private final int[] parent;
    private final int[] rank;

    public UnionFind(int n) {
        parent = new int[n];
        rank = new int[n];
        for (int i = 0; i < n; i++) parent[i] = i;
    }

    public int find(int x) {
        if (parent[x] != x) {
            parent[x] = find(parent[x]); // path compression
        }
        return parent[x];
    }

    public boolean union(int a, int b) {
        int rootA = find(a);
        int rootB = find(b);
        if (rootA == rootB) return false; // already in the same set

        if (rank[rootA] < rank[rootB]) {
            parent[rootA] = rootB;
        } else if (rank[rootA] > rank[rootB]) {
            parent[rootB] = rootA;
        } else {
            parent[rootB] = rootA;
            rank[rootA]++;
        }
        return true;
    }

    public boolean connected(int a, int b) {
        return find(a) == find(b);
    }

    public static void main(String[] args) {
        UnionFind uf = new UnionFind(10);

        uf.union(1, 2);
        uf.union(2, 3);
        uf.union(4, 5);
        uf.union(6, 7);
        uf.union(5, 6);

        System.out.println("connected(1, 3): " + uf.connected(1, 3)); // true, 1-2-3
        System.out.println("connected(1, 4): " + uf.connected(1, 4)); // false, different groups
        System.out.println("connected(4, 7): " + uf.connected(4, 7)); // true, 4-5-6-7

        uf.union(3, 4); // merges {1,2,3} with {4,5,6,7}
        System.out.println("After union(3, 4), connected(1, 7): " + uf.connected(1, 7)); // true now

        System.out.println("connected(8, 9): " + uf.connected(8, 9)); // false, untouched singletons
    }
}
