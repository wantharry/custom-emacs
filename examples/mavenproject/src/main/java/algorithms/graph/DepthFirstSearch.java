import java.util.ArrayList;
import java.util.List;

/**
 * DEPTH-FIRST SEARCH (DFS)
 *
 * What it does:
 *   Traverses a graph by going as deep as possible along one path before
 *   backtracking. It is used to discover connectivity, detect cycles,
 *   compute topological orderings, and explore all reachable vertices
 *   from a given source.
 *
 * Core idea / how it works:
 *   Starting at a vertex, mark it visited, then recursively visit an
 *   unvisited neighbor. Only when a vertex has no more unvisited
 *   neighbors does the recursion unwind ("backtrack") to try the next
 *   sibling branch. This naturally produces a stack-like exploration
 *   order (last vertex found is the first one backed out of), which can
 *   be implemented either with real recursion (the call stack) or with an
 *   explicit Stack data structure.
 *
 * Time complexity:  O(V + E)  -- each vertex is visited once, each edge
 *                                examined once.
 * Space complexity: O(V)      -- visited array plus recursion stack depth
 *                                (worst case O(V) for a path-like graph).
 */
public class DepthFirstSearch {

    private static void dfsVisit(List<List<Integer>> adj, int u, boolean[] visited, List<Integer> order) {
        visited[u] = true;
        order.add(u);
        for (int v : adj.get(u)) {
            if (!visited[v]) {
                dfsVisit(adj, v, visited, order);
            }
        }
    }

    /** Runs DFS from the given source and returns the order in which vertices were first visited. */
    public static List<Integer> dfs(List<List<Integer>> adj, int source) {
        boolean[] visited = new boolean[adj.size()];
        List<Integer> order = new ArrayList<>();
        dfsVisit(adj, source, visited, order);
        return order;
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
        List<Integer> order = dfs(adj, source);
        System.out.println("DFS visit order starting from node " + source + ": " + order);
    }
}
