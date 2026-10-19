import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;

/**
 * TARJAN'S STRONGLY CONNECTED COMPONENTS (SCC) ALGORITHM
 *
 * What it does:
 *   Finds all Strongly Connected Components of a directed graph in a
 *   SINGLE DFS pass (as opposed to Kosaraju's two-pass approach).
 *
 * Core idea / how it works:
 *   Run one DFS, assigning each vertex a discovery index ("disc") in the
 *   order it is first visited, and a "low-link" value: the smallest
 *   discovery index reachable from that vertex using at most one "back
 *   edge" to an ancestor still on the current DFS stack. Keep an explicit
 *   stack of vertices currently "in progress". After exploring all of a
 *   vertex's neighbors, if its low-link equals its own discovery index,
 *   it is the root of an SCC -- pop vertices off the stack down to and
 *   including it; everything popped forms that SCC. The low-link
 *   propagation is what lets a whole cycle collapse into one component
 *   without a second graph traversal.
 *
 * Time complexity:  O(V + E)  -- a single DFS traversal.
 * Space complexity: O(V)      -- disc/low arrays, on-stack flags, and the explicit stack.
 */
public class TarjanSCC {

    private int[] disc, low;
    private boolean[] onStack;
    private Deque<Integer> stack;
    private int index;
    private List<List<Integer>> sccs;
    private List<List<Integer>> adj;

    private void strongConnect(int u) {
        disc[u] = low[u] = index++;
        stack.push(u);
        onStack[u] = true;

        for (int v : adj.get(u)) {
            if (disc[v] == -1) {
                strongConnect(v);
                low[u] = Math.min(low[u], low[v]);
            } else if (onStack[v]) {
                low[u] = Math.min(low[u], disc[v]);
            }
        }

        if (low[u] == disc[u]) {
            List<Integer> component = new ArrayList<>();
            int w;
            do {
                w = stack.pop();
                onStack[w] = false;
                component.add(w);
            } while (w != u);
            sccs.add(component);
        }
    }

    public List<List<Integer>> findSCCs(List<List<Integer>> graph) {
        this.adj = graph;
        int n = graph.size();
        disc = new int[n];
        low = new int[n];
        onStack = new boolean[n];
        java.util.Arrays.fill(disc, -1);
        stack = new ArrayDeque<>();
        index = 0;
        sccs = new ArrayList<>();

        for (int i = 0; i < n; i++) {
            if (disc[i] == -1) strongConnect(i);
        }
        return sccs;
    }

    public static void main(String[] args) {
        // Same directed graph as the Kosaraju example, 8 nodes (0..7).
        int n = 8;
        List<List<Integer>> adj = new ArrayList<>();
        for (int i = 0; i < n; i++) adj.add(new ArrayList<>());

        int[][] edges = {{0, 1}, {1, 2}, {2, 0}, {1, 3}, {3, 4}, {4, 5}, {5, 3}, {5, 6}, {6, 7}};
        for (int[] e : edges) adj.get(e[0]).add(e[1]);

        System.out.println("Directed graph adjacency list:");
        for (int i = 0; i < n; i++) System.out.println("  " + i + " -> " + adj.get(i));

        TarjanSCC solver = new TarjanSCC();
        List<List<Integer>> sccs = solver.findSCCs(adj);
        System.out.println("Strongly Connected Components found: " + sccs.size());
        for (List<Integer> component : sccs) {
            System.out.println("  " + component);
        }
    }
}
