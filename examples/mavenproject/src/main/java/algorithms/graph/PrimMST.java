import java.util.ArrayList;
import java.util.List;
import java.util.PriorityQueue;

/**
 * PRIM'S MINIMUM SPANNING TREE ALGORITHM
 *
 * What it does:
 *   Given a connected, undirected, weighted graph, finds a Minimum
 *   Spanning Tree (MST) -- a subset of edges connecting all vertices with
 *   minimum total weight and no cycles. Unlike Kruskal (which sorts all
 *   edges globally), Prim grows a single tree outward one vertex at a time.
 *
 * Core idea / how it works:
 *   Start the tree with an arbitrary vertex. Maintain a min-priority-queue
 *   of candidate edges that connect the current tree to a vertex not yet
 *   in the tree. Repeatedly pop the cheapest such edge; if its far
 *   endpoint is already in the tree, discard it (it would form a cycle);
 *   otherwise add that vertex to the tree, add the edge to the MST, and
 *   push all of the new vertex's edges to vertices outside the tree as
 *   new candidates.
 *
 * Time complexity:  O(E log V)  -- each edge may be pushed to the heap once,
 *                                  each heap operation is O(log E) ~ O(log V).
 * Space complexity: O(V + E)    -- adjacency list, visited set and the heap.
 */
public class PrimMST {

    /** adj.get(u) = list of int[]{neighbor, weight}. Returns the chosen MST edges as int[]{u, v, weight}. */
    public static List<int[]> prim(List<List<int[]>> adj, int start) {
        int n = adj.size();
        boolean[] inTree = new boolean[n];
        List<int[]> mst = new ArrayList<>();

        // Heap entries: {weight, from, to}
        PriorityQueue<int[]> pq = new PriorityQueue<>((a, b) -> Integer.compare(a[0], b[0]));
        inTree[start] = true;
        for (int[] edge : adj.get(start)) {
            pq.add(new int[]{edge[1], start, edge[0]});
        }

        while (!pq.isEmpty() && mst.size() < n - 1) {
            int[] top = pq.poll();
            int weight = top[0], from = top[1], to = top[2];
            if (inTree[to]) continue;

            inTree[to] = true;
            mst.add(new int[]{from, to, weight});
            for (int[] edge : adj.get(to)) {
                if (!inTree[edge[0]]) {
                    pq.add(new int[]{edge[1], to, edge[0]});
                }
            }
        }
        return mst;
    }

    public static void main(String[] args) {
        // Undirected weighted graph, 6 nodes (0..5).
        int n = 6;
        List<List<int[]>> adj = new ArrayList<>();
        for (int i = 0; i < n; i++) adj.add(new ArrayList<>());

        int[][] raw = {{0, 1, 4}, {0, 2, 4}, {1, 2, 2}, {2, 3, 3}, {2, 5, 2},
                        {2, 4, 4}, {3, 4, 3}, {4, 5, 3}};
        for (int[] e : raw) {
            adj.get(e[0]).add(new int[]{e[1], e[2]});
            adj.get(e[1]).add(new int[]{e[0], e[2]});
        }

        System.out.println("Undirected weighted adjacency list:");
        for (int i = 0; i < n; i++) {
            StringBuilder sb = new StringBuilder("  " + i + " -> ");
            for (int[] e : adj.get(i)) sb.append("(").append(e[0]).append(",w=").append(e[1]).append(") ");
            System.out.println(sb);
        }

        List<int[]> mst = prim(adj, 0);
        int total = 0;
        System.out.println("Minimum Spanning Tree edges:");
        for (int[] e : mst) {
            System.out.println("  " + e[0] + " - " + e[1] + " (w=" + e[2] + ")");
            total += e[2];
        }
        System.out.println("Total MST weight: " + total);
    }
}
