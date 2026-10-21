import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Queue;

/**
 * BREADTH-FIRST SEARCH (BFS)
 *
 * What it does:
 *   Traverses a graph level by level starting from a source vertex, visiting
 *   all neighbors at the current distance before moving further away. It is
 *   the standard way to find shortest paths in an UNWEIGHTED graph (every
 *   edge counts as "1 step"), and to discover connected components.
 *
 * Core idea / how it works:
 *   Use a FIFO queue. Start by pushing the source vertex and marking it
 *   visited. Repeatedly pop a vertex from the front of the queue, look at
 *   each of its unvisited neighbors, mark them visited, record their
 *   distance (parent's distance + 1), and push them to the back of the
 *   queue. Because the queue is FIFO, vertices are always processed in
 *   non-decreasing order of distance from the source, which is exactly why
 *   the first time a vertex is reached gives its shortest hop-count.
 *
 * Time complexity:  O(V + E)  -- every vertex is dequeued once and every
 *                                edge is examined once (adjacency-list graph).
 * Space complexity: O(V)      -- visited array, distance array and the queue.
 */
public class BreadthFirstSearch {

    /** Runs BFS from a source vertex and returns the shortest hop-distance to every vertex. */
    public static int[] bfs(List<List<Integer>> adj, int source) {
        int n = adj.size();
        int[] distance = new int[n];
        boolean[] visited = new boolean[n];
        java.util.Arrays.fill(distance, -1);

        Queue<Integer> queue = new ArrayDeque<>();
        visited[source] = true;
        distance[source] = 0;
        queue.add(source);

        List<Integer> order = new ArrayList<>();
        while (!queue.isEmpty()) {
            int u = queue.poll();
            order.add(u);
            for (int v : adj.get(u)) {
                if (!visited[v]) {
                    visited[v] = true;
                    distance[v] = distance[u] + 1;
                    queue.add(v);
                }
            }
        }
        System.out.println("Visit order: " + order);
        return distance;
    }

    public static void main(String[] args) {
        // Build a small undirected graph with 6 nodes (0..5):
        //   0 - 1, 0 - 2, 1 - 3, 2 - 3, 3 - 4, 4 - 5
        int n = 6;
        List<List<Integer>> adj = new ArrayList<>();
        for (int i = 0; i < n; i++) adj.add(new ArrayList<>());

        int[][] edges = {{0, 1}, {0, 2}, {1, 3}, {2, 3}, {3, 4}, {4, 5}};
        for (int[] e : edges) {
            adj.get(e[0]).add(e[1]);
            adj.get(e[1]).add(e[0]);
        }

        System.out.println("Graph adjacency list:");
        for (int i = 0; i < n; i++) System.out.println("  " + i + " -> " + adj.get(i));

        int source = 0;
        int[] dist = bfs(adj, source);

        System.out.println("Shortest hop-distances from node " + source + ":");
        for (int i = 0; i < n; i++) {
            System.out.println("  distance[" + i + "] = " + dist[i]);
        }
    }
}
