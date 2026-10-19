import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * KRUSKAL'S MINIMUM SPANNING TREE ALGORITHM
 *
 * What it does:
 *   Given a connected, undirected, weighted graph, finds a Minimum
 *   Spanning Tree (MST) -- a subset of edges that connects all vertices
 *   together with the minimum possible total edge weight and no cycles.
 *
 * Core idea / how it works:
 *   Greedy approach using a Union-Find (Disjoint Set Union) structure.
 *   Sort all edges by weight, ascending. Walk through them in order and
 *   add an edge to the MST only if its two endpoints are not already in
 *   the same connected component (i.e. adding it would not create a
 *   cycle). Union-Find answers "same component?" and merges components
 *   in near-constant time. Stop once V-1 edges have been added.
 *
 * Time complexity:  O(E log E)  -- dominated by sorting the edges; Union-
 *                                  Find operations are near O(1) amortized
 *                                  with path compression + union by rank.
 * Space complexity: O(V + E)    -- edge list plus the Union-Find parent/rank arrays.
 */
public class KruskalMST {

    static class DisjointSet {
        int[] parent, rank;
        DisjointSet(int n) {
            parent = new int[n];
            rank = new int[n];
            for (int i = 0; i < n; i++) parent[i] = i;
        }
        int find(int x) {
            if (parent[x] != x) parent[x] = find(parent[x]);
            return parent[x];
        }
        boolean union(int a, int b) {
            int ra = find(a), rb = find(b);
            if (ra == rb) return false;
            if (rank[ra] < rank[rb]) { int t = ra; ra = rb; rb = t; }
            parent[rb] = ra;
            if (rank[ra] == rank[rb]) rank[ra]++;
            return true;
        }
    }

    /** edges: int[]{u, v, weight}. Returns the chosen MST edges. */
    public static List<int[]> kruskal(int n, List<int[]> edges) {
        List<int[]> sorted = new ArrayList<>(edges);
        sorted.sort((a, b) -> Integer.compare(a[2], b[2]));

        DisjointSet dsu = new DisjointSet(n);
        List<int[]> mst = new ArrayList<>();
        for (int[] e : sorted) {
            if (dsu.union(e[0], e[1])) {
                mst.add(e);
                if (mst.size() == n - 1) break;
            }
        }
        return mst;
    }

    public static void main(String[] args) {
        // Undirected weighted graph, 6 nodes (0..5).
        int n = 6;
        List<int[]> edges = new ArrayList<>();
        int[][] raw = {{0, 1, 4}, {0, 2, 4}, {1, 2, 2}, {1, 0, 4}, {2, 3, 3}, {2, 5, 2},
                        {2, 4, 4}, {3, 4, 3}, {4, 5, 3}};
        for (int[] e : raw) edges.add(e);

        System.out.println("Undirected weighted edges (u, v, weight):");
        for (int[] e : edges) System.out.println("  " + e[0] + " - " + e[1] + " (w=" + e[2] + ")");

        List<int[]> mst = kruskal(n, edges);
        int total = 0;
        System.out.println("Minimum Spanning Tree edges:");
        for (int[] e : mst) {
            System.out.println("  " + e[0] + " - " + e[1] + " (w=" + e[2] + ")");
            total += e[2];
        }
        System.out.println("Total MST weight: " + total);
    }
}
