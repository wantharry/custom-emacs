import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

/**
 * KOSARAJU'S STRONGLY CONNECTED COMPONENTS (SCC) ALGORITHM
 *
 * What it does:
 *   Finds all Strongly Connected Components of a directed graph -- maximal
 *   groups of vertices where every vertex can reach every other vertex in
 *   the same group via directed edges.
 *
 * Core idea / how it works:
 *   Three steps. (1) Run DFS on the original graph, and whenever a DFS
 *   call finishes exploring a vertex (post-order), push it onto a stack.
 *   This produces vertices ordered so that "later-finishing" vertices
 *   come first on top. (2) Reverse every edge in the graph (transpose).
 *   (3) Pop vertices off the stack one at a time; for each not-yet-visited
 *   vertex, run DFS on the TRANSPOSED graph from it -- everything reached
 *   in that DFS forms exactly one SCC. The reasoning: processing in
 *   decreasing finish-time order on the transpose guarantees each DFS
 *   call stays within a single SCC and discovers the whole thing.
 *
 * Time complexity:  O(V + E)  -- two DFS passes plus building the transpose.
 * Space complexity: O(V + E)  -- original graph, transpose graph, stack, visited arrays.
 */
public class KosarajuSCC {

    private static void fillOrder(List<List<Integer>> adj, int u, boolean[] visited, Deque<Integer> stack) {
        visited[u] = true;
        for (int v : adj.get(u)) {
            if (!visited[v]) fillOrder(adj, v, visited, stack);
        }
        stack.push(u);
    }

    private static void collectComponent(List<List<Integer>> transpose, int u, boolean[] visited, List<Integer> component) {
        visited[u] = true;
        component.add(u);
        for (int v : transpose.get(u)) {
            if (!visited[v]) collectComponent(transpose, v, visited, component);
        }
    }

    public static List<List<Integer>> kosaraju(List<List<Integer>> adj) {
        int n = adj.size();

        // Step 1: order vertices by DFS finish time.
        boolean[] visited = new boolean[n];
        Deque<Integer> stack = new ArrayDeque<>();
        for (int i = 0; i < n; i++) {
            if (!visited[i]) fillOrder(adj, i, visited, stack);
        }

        // Step 2: build the transpose graph (reverse every edge).
        List<List<Integer>> transpose = new ArrayList<>();
        for (int i = 0; i < n; i++) transpose.add(new ArrayList<>());
        for (int u = 0; u < n; u++) {
            for (int v : adj.get(u)) transpose.get(v).add(u);
        }

        // Step 3: DFS on the transpose in the order from the stack.
        java.util.Arrays.fill(visited, false);
        List<List<Integer>> sccs = new ArrayList<>();
        while (!stack.isEmpty()) {
            int u = stack.pop();
            if (!visited[u]) {
                List<Integer> component = new ArrayList<>();
                collectComponent(transpose, u, visited, component);
                sccs.add(component);
            }
        }
        return sccs;
    }

    public static void main(String[] args) {
        // Directed graph, 8 nodes (0..7), with two SCCs plus singleton-ish structure.
        int n = 8;
        List<List<Integer>> adj = new ArrayList<>();
        for (int i = 0; i < n; i++) adj.add(new ArrayList<>());

        int[][] edges = {{0, 1}, {1, 2}, {2, 0}, {1, 3}, {3, 4}, {4, 5}, {5, 3}, {5, 6}, {6, 7}};
        for (int[] e : edges) adj.get(e[0]).add(e[1]);

        System.out.println("Directed graph adjacency list:");
        for (int i = 0; i < n; i++) System.out.println("  " + i + " -> " + adj.get(i));

        List<List<Integer>> sccs = kosaraju(adj);
        System.out.println("Strongly Connected Components found: " + sccs.size());
        for (List<Integer> component : sccs) {
            System.out.println("  " + component);
        }
    }
}
