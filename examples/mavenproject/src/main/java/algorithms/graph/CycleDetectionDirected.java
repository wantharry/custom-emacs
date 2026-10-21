import java.util.ArrayList;
import java.util.List;

/**
 * CYCLE DETECTION IN A DIRECTED GRAPH (DFS with coloring)
 *
 * What it does:
 *   Determines whether a directed graph contains at least one cycle.
 *   This is essential for validating DAG assumptions (e.g. before running
 *   topological sort) and for detecting deadlock-like dependency loops.
 *
 * Core idea / how it works:
 *   Three-color DFS. WHITE = never visited, GRAY = currently on the DFS
 *   recursion stack (an ancestor of the current call), BLACK = fully
 *   finished (explored completely, including all descendants). While
 *   doing DFS from a vertex, mark it GRAY on entry and BLACK on exit. If
 *   at any point we follow an edge u -> v and find v is GRAY, that means
 *   v is an ancestor of u in the current DFS path -- so the edge u -> v
 *   closes a cycle back to an ancestor ("back edge"). If v is BLACK, it
 *   was already fully explored via some other path and is safe (a "cross
 *   edge" or "forward edge" in DAG terms) -- not a cycle.
 *
 * Time complexity:  O(V + E)  -- a single DFS traversal.
 * Space complexity: O(V)      -- color array and recursion stack.
 */
public class CycleDetectionDirected {

    private static final int WHITE = 0, GRAY = 1, BLACK = 2;

    private static boolean dfs(List<List<Integer>> adj, int u, int[] color) {
        color[u] = GRAY;
        for (int v : adj.get(u)) {
            if (color[v] == GRAY) {
                return true; // back edge to an ancestor -> cycle
            }
            if (color[v] == WHITE && dfs(adj, v, color)) {
                return true;
            }
        }
        color[u] = BLACK;
        return false;
    }

    public static boolean hasCycle(List<List<Integer>> adj) {
        int n = adj.size();
        int[] color = new int[n];
        for (int i = 0; i < n; i++) {
            if (color[i] == WHITE && dfs(adj, i, color)) {
                return true;
            }
        }
        return false;
    }

    public static void main(String[] args) {
        // Example 1: a directed graph WITH a cycle (3 -> 4 -> 1 -> 3).
        int n1 = 5;
        List<List<Integer>> withCycle = new ArrayList<>();
        for (int i = 0; i < n1; i++) withCycle.add(new ArrayList<>());
        int[][] edges1 = {{0, 1}, {1, 2}, {1, 3}, {3, 4}, {4, 1}};
        for (int[] e : edges1) withCycle.get(e[0]).add(e[1]);

        System.out.println("Graph 1 adjacency list: ");
        for (int i = 0; i < n1; i++) System.out.println("  " + i + " -> " + withCycle.get(i));
        System.out.println("Has cycle? " + hasCycle(withCycle));

        // Example 2: a directed graph WITHOUT a cycle (a DAG).
        int n2 = 5;
        List<List<Integer>> noCycle = new ArrayList<>();
        for (int i = 0; i < n2; i++) noCycle.add(new ArrayList<>());
        int[][] edges2 = {{0, 1}, {0, 2}, {1, 3}, {2, 3}, {3, 4}};
        for (int[] e : edges2) noCycle.get(e[0]).add(e[1]);

        System.out.println("Graph 2 adjacency list: ");
        for (int i = 0; i < n2; i++) System.out.println("  " + i + " -> " + noCycle.get(i));
        System.out.println("Has cycle? " + hasCycle(noCycle));
    }
}
