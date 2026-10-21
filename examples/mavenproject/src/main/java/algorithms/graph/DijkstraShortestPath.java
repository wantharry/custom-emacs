import java.util.ArrayList;
import java.util.List;
import java.util.PriorityQueue;

/**
 * DIJKSTRA'S SHORTEST PATH ALGORITHM
 *
 * What it does:
 *   Finds the shortest-distance path from a single source vertex to every
 *   other vertex in a weighted graph, provided all edge weights are
 *   NON-NEGATIVE.
 *
 * Core idea / how it works:
 *   Greedily grow a set of vertices whose shortest distance is already
 *   known. Keep a min-priority-queue of (distance, vertex) pairs. Always
 *   pop the vertex with the smallest tentative distance -- once popped,
 *   that distance is guaranteed final because every edge weight is
 *   non-negative (nothing cheaper can appear later). Then "relax" every
 *   outgoing edge: if going through the popped vertex gives a shorter
 *   path to a neighbor than previously known, update the neighbor's
 *   distance and push it back into the queue.
 *
 * Time complexity:  O((V + E) log V) using a binary-heap priority queue.
 * Space complexity: O(V + E) for the adjacency list, distance array and queue.
 */
public class DijkstraShortestPath {

    /** adj.get(u) is a list of int[]{neighbor, weight} pairs. */
    public static int[] dijkstra(List<List<int[]>> adj, int source) {
        int n = adj.size();
        int[] dist = new int[n];
        java.util.Arrays.fill(dist, Integer.MAX_VALUE);
        dist[source] = 0;

        // Min-heap ordered by current best known distance.
        PriorityQueue<int[]> pq = new PriorityQueue<>((a, b) -> Integer.compare(a[1], b[1]));
        pq.add(new int[]{source, 0});
        boolean[] finalized = new boolean[n];

        while (!pq.isEmpty()) {
            int[] top = pq.poll();
            int u = top[0];
            if (finalized[u]) continue;
            finalized[u] = true;

            for (int[] edge : adj.get(u)) {
                int v = edge[0];
                int weight = edge[1];
                if (!finalized[v] && dist[u] != Integer.MAX_VALUE && dist[u] + weight < dist[v]) {
                    dist[v] = dist[u] + weight;
                    pq.add(new int[]{v, dist[v]});
                }
            }
        }
        return dist;
    }

    public static void main(String[] args) {
        // Weighted directed graph, 6 nodes (0..5):
        //   0 -> 1 (4), 0 -> 2 (1), 2 -> 1 (2), 1 -> 3 (1),
        //   2 -> 3 (5), 3 -> 4 (3), 4 -> 5 (2), 2 -> 4 (8)
        int n = 6;
        List<List<int[]>> adj = new ArrayList<>();
        for (int i = 0; i < n; i++) adj.add(new ArrayList<>());

        int[][] edges = {{0, 1, 4}, {0, 2, 1}, {2, 1, 2}, {1, 3, 1}, {2, 3, 5}, {3, 4, 3}, {4, 5, 2}, {2, 4, 8}};
        for (int[] e : edges) adj.get(e[0]).add(new int[]{e[1], e[2]});

        System.out.println("Weighted directed graph (node -> [neighbor, weight]):");
        for (int i = 0; i < n; i++) {
            StringBuilder sb = new StringBuilder("  " + i + " -> ");
            for (int[] e : adj.get(i)) sb.append("(").append(e[0]).append(",w=").append(e[1]).append(") ");
            System.out.println(sb);
        }

        int source = 0;
        int[] dist = dijkstra(adj, source);
        System.out.println("Shortest distances from node " + source + ":");
        for (int i = 0; i < n; i++) {
            System.out.println("  dist[" + i + "] = " + (dist[i] == Integer.MAX_VALUE ? "unreachable" : dist[i]));
        }
    }
}
