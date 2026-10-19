import java.util.ArrayList;
import java.util.List;

/**
 * CYCLE DETECTION IN AN UNDIRECTED GRAPH (DFS with parent tracking)
 *
 * What it does:
 *   Determines whether an undirected graph contains at least one cycle.
 *   Useful for checking whether a graph is a tree/forest (trees have no
 *   cycles), and as a building block for algorithms like Kruskal's MST.
 *
 * Core idea / how it works:
 *   DFS from each unvisited vertex, remembering the "parent" vertex that
 *   the DFS call came from. For each neighbor v of the current vertex u:
 *   if v is unvisited, recurse into it with u as its parent; if v IS
 *   visited and v is NOT the immediate parent of u, then we've reached an
 *   already-visited vertex through a different path than the tree edge
 *   that brought us here -- that is a cycle. (The parent check is needed
 *   because in an undirected graph every edge u-v is stored twice, as
 *   u->v and v->u, so without it the trivial "bounce back to parent"
 *   would be wrongly flagged as a cycle.)
 *
 * Time complexity:  O(V + E)  -- a single DFS traversal.
 * Space complexity: O(V)      -- visited array and recursion stack.
 */
public class CycleDetectionUndirected {

    private static boolean dfs(List<List<Integer>> adj, int u, int parent, boolean[] visited) {
        visited[u] = true;
        for (int v : adj.get(u)) {
            if (!visited[v]) {
                if (dfs(adj, v, u, visited)) return true;
            } else if (v != parent) {
                return true; // reached a visited vertex that isn't our parent -> cycle
            }
        }
        return false;
    }

    public static boolean hasCycle(List<List<Integer>> adj) {
        int n = adj.size();
        boolean[] visited = new boolean[n];
        for (int i = 0; i < n; i++) {
            if (!visited[i] && dfs(adj, i, -1, visited)) {
                return true;
            }
        }
        return false;
    }

    public static void main(String[] args) {
        // Example 1: an undirected graph WITH a cycle (0-1-2-0 triangle, plus 2-3-4 branch).
        int n1 = 5;
        List<List<Integer>> withCycle = new ArrayList<>();
        for (int i = 0; i < n1; i++) withCycle.add(new ArrayList<>());
        int[][] edges1 = {{0, 1}, {1, 2}, {2, 0}, {2, 3}, {3, 4}};
        for (int[] e : edges1) {
            withCycle.get(e[0]).add(e[1]);
            withCycle.get(e[1]).add(e[0]);
        }

        System.out.println("Graph 1 adjacency list:");
        for (int i = 0; i < n1; i++) System.out.println("  " + i + " -> " + withCycle.get(i));
        System.out.println("Has cycle? " + hasCycle(withCycle));

        // Example 2: an undirected tree (no cycle).
        int n2 = 5;
        List<List<Integer>> noCycle = new ArrayList<>();
        for (int i = 0; i < n2; i++) noCycle.add(new ArrayList<>());
        int[][] edges2 = {{0, 1}, {0, 2}, {1, 3}, {1, 4}};
        for (int[] e : edges2) {
            noCycle.get(e[0]).add(e[1]);
            noCycle.get(e[1]).add(e[0]);
        }

        System.out.println("Graph 2 adjacency list:");
        for (int i = 0; i < n2; i++) System.out.println("  " + i + " -> " + noCycle.get(i));
        System.out.println("Has cycle? " + hasCycle(noCycle));
    }
}
