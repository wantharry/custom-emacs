import java.util.ArrayList;
import java.util.List;

/**
 * BELLMAN-FORD SHORTEST PATH ALGORITHM
 *
 * What it does:
 *   Finds the shortest-distance path from a single source vertex to every
 *   other vertex in a weighted directed graph, and -- unlike Dijkstra --
 *   correctly handles NEGATIVE edge weights. It can also detect whether
 *   the graph contains a negative-weight cycle (in which case "shortest
 *   path" is undefined, since you could loop forever reducing the cost).
 *
 * Core idea / how it works:
 *   Repeatedly "relax" every edge (u, v, w): if dist[u] + w < dist[v],
 *   improve dist[v]. After relaxing every edge in the graph, the shortest
 *   path using at most 1 edge is correct. After doing a full relaxation
 *   pass over all edges V-1 times, every shortest path using at most V-1
 *   edges is guaranteed correct (and any simple shortest path has at most
 *   V-1 edges, so this covers all of them for graphs without negative
 *   cycles). A final extra pass is done: if any edge can still be relaxed,
 *   a negative cycle exists.
 *
 * Time complexity:  O(V * E)  -- V-1 relaxation passes, each pass O(E).
 * Space complexity: O(V + E)  -- edge list and distance array.
 */
public class BellmanFord {

    private static final int INF = Integer.MAX_VALUE;

    /** edges[i] = {from, to, weight}. Returns distances, or null if a negative cycle is detected. */
    public static int[] bellmanFord(int n, List<int[]> edges, int source) {
        int[] dist = new int[n];
        java.util.Arrays.fill(dist, INF);
        dist[source] = 0;

        for (int iteration = 0; iteration < n - 1; iteration++) {
            boolean changed = false;
            for (int[] e : edges) {
                int u = e[0], v = e[1], w = e[2];
                if (dist[u] != INF && dist[u] + w < dist[v]) {
                    dist[v] = dist[u] + w;
                    changed = true;
                }
            }
            if (!changed) break; // early exit: converged
        }

        // One more pass: if anything still improves, there's a negative cycle.
        for (int[] e : edges) {
            int u = e[0], v = e[1], w = e[2];
            if (dist[u] != INF && dist[u] + w < dist[v]) {
                return null;
            }
        }
        return dist;
    }

    public static void main(String[] args) {
        // Directed graph, 5 nodes (0..4), with one negative edge but no negative cycle:
        //   0 -> 1 (6), 0 -> 2 (7), 1 -> 2 (8), 1 -> 3 (5), 1 -> 4 (-4),
        //   2 -> 3 (-3), 2 -> 4 (9), 3 -> 1 (-2), 4 -> 3 (7), 4 -> 0 (2)
        int n = 5;
        List<int[]> edges = new ArrayList<>();
        int[][] raw = {{0, 1, 6}, {0, 2, 7}, {1, 2, 8}, {1, 3, 5}, {1, 4, -4},
                        {2, 3, -3}, {2, 4, 9}, {3, 1, -2}, {4, 3, 7}, {4, 0, 2}};
        for (int[] e : raw) edges.add(e);

        System.out.println("Directed edge list (from, to, weight):");
        for (int[] e : edges) System.out.println("  " + e[0] + " -> " + e[1] + " (w=" + e[2] + ")");

        int source = 0;
        int[] dist = bellmanFord(n, edges, source);
        if (dist == null) {
            System.out.println("Negative-weight cycle detected! No well-defined shortest paths.");
        } else {
            System.out.println("Shortest distances from node " + source + ":");
            for (int i = 0; i < n; i++) {
                System.out.println("  dist[" + i + "] = " + dist[i]);
            }
        }
    }
}
