import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Queue;

/**
 * BIPARTITE GRAPH CHECK (2-coloring via BFS)
 *
 * What it does:
 *   Determines whether a graph is bipartite -- that is, whether its
 *   vertices can be split into two groups such that every edge connects
 *   a vertex in one group to a vertex in the other (no edge stays within
 *   the same group). Bipartiteness matters for matching problems,
 *   scheduling conflicts, and is equivalent to "the graph has no odd-length cycle".
 *
 * Core idea / how it works:
 *   Try to 2-color the graph using BFS. Color the BFS source with color 0.
 *   For every edge from the current vertex to a neighbor, the neighbor
 *   must get the OPPOSITE color. If the neighbor is uncolored, color it
 *   and continue. If it is already colored and happens to match the
 *   current vertex's color, that's a contradiction -- an edge connects
 *   two same-colored vertices, which is impossible in a valid
 *   2-coloring, so the graph is not bipartite. Repeat for every connected
 *   component (a graph can have several).
 *
 * Time complexity:  O(V + E)  -- each vertex and edge visited once.
 * Space complexity: O(V)      -- color array and BFS queue.
 */
public class BipartiteGraphCheck {

    public static boolean isBipartite(List<List<Integer>> adj) {
        int n = adj.size();
        int[] color = new int[n];
        java.util.Arrays.fill(color, -1);

        for (int start = 0; start < n; start++) {
            if (color[start] != -1) continue;
            color[start] = 0;
            Queue<Integer> queue = new ArrayDeque<>();
            queue.add(start);

            while (!queue.isEmpty()) {
                int u = queue.poll();
                for (int v : adj.get(u)) {
                    if (color[v] == -1) {
                        color[v] = 1 - color[u];
                        queue.add(v);
                    } else if (color[v] == color[u]) {
                        return false; // same-colored neighbors -> odd cycle -> not bipartite
                    }
                }
            }
        }
        return true;
    }

    public static void main(String[] args) {
        // Example 1: bipartite graph -- an even cycle 0-1-2-3-4-5-0.
        int n1 = 6;
        List<List<Integer>> bip = new ArrayList<>();
        for (int i = 0; i < n1; i++) bip.add(new ArrayList<>());
        int[][] edges1 = {{0, 1}, {1, 2}, {2, 3}, {3, 4}, {4, 5}, {5, 0}};
        for (int[] e : edges1) {
            bip.get(e[0]).add(e[1]);
            bip.get(e[1]).add(e[0]);
        }
        System.out.println("Graph 1 (even 6-cycle) adjacency list:");
        for (int i = 0; i < n1; i++) System.out.println("  " + i + " -> " + bip.get(i));
        System.out.println("Is bipartite? " + isBipartite(bip));

        // Example 2: non-bipartite graph -- a triangle 0-1-2-0 (odd cycle).
        int n2 = 5;
        List<List<Integer>> notBip = new ArrayList<>();
        for (int i = 0; i < n2; i++) notBip.add(new ArrayList<>());
        int[][] edges2 = {{0, 1}, {1, 2}, {2, 0}, {2, 3}, {3, 4}};
        for (int[] e : edges2) {
            notBip.get(e[0]).add(e[1]);
            notBip.get(e[1]).add(e[0]);
        }
        System.out.println("Graph 2 (triangle + tail) adjacency list:");
        for (int i = 0; i < n2; i++) System.out.println("  " + i + " -> " + notBip.get(i));
        System.out.println("Is bipartite? " + isBipartite(notBip));
    }
}
