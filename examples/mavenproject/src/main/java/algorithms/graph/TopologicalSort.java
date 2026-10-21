import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Queue;

/**
 * TOPOLOGICAL SORT (Kahn's Algorithm, BFS-based)
 *
 * What it does:
 *   Produces a linear ordering of the vertices of a Directed Acyclic
 *   Graph (DAG) such that for every directed edge u -> v, u appears
 *   before v in the ordering. Classic use cases: task scheduling with
 *   dependencies, build systems, course prerequisites.
 *
 * Core idea / how it works:
 *   Compute the in-degree (number of incoming edges) of every vertex.
 *   Any vertex with in-degree 0 has no unmet dependency, so it can be
 *   placed next. Put all in-degree-0 vertices in a queue. Repeatedly pop
 *   a vertex, append it to the result, and "remove" it from the graph by
 *   decrementing the in-degree of each of its neighbors -- any neighbor
 *   whose in-degree drops to 0 is now also ready and gets queued. If the
 *   result ends up shorter than the number of vertices, the graph has a
 *   cycle and no valid topological order exists.
 *
 * Time complexity:  O(V + E)  -- each vertex and edge processed once.
 * Space complexity: O(V + E)  -- adjacency list, in-degree array and queue.
 */
public class TopologicalSort {

    /** Returns a valid topological order, or an empty list if the graph has a cycle. */
    public static List<Integer> topologicalSort(List<List<Integer>> adj) {
        int n = adj.size();
        int[] inDegree = new int[n];
        for (List<Integer> neighbors : adj) {
            for (int v : neighbors) inDegree[v]++;
        }

        Queue<Integer> ready = new ArrayDeque<>();
        for (int i = 0; i < n; i++) {
            if (inDegree[i] == 0) ready.add(i);
        }

        List<Integer> order = new ArrayList<>();
        while (!ready.isEmpty()) {
            int u = ready.poll();
            order.add(u);
            for (int v : adj.get(u)) {
                inDegree[v]--;
                if (inDegree[v] == 0) ready.add(v);
            }
        }

        if (order.size() != n) {
            return new ArrayList<>(); // cycle detected -- no valid ordering
        }
        return order;
    }

    public static void main(String[] args) {
        // DAG representing course prerequisites, 6 courses (0..5):
        //   0 -> 1, 0 -> 2, 1 -> 3, 2 -> 3, 3 -> 4, 1 -> 4, 4 -> 5
        int n = 6;
        List<List<Integer>> adj = new ArrayList<>();
        for (int i = 0; i < n; i++) adj.add(new ArrayList<>());

        int[][] edges = {{0, 1}, {0, 2}, {1, 3}, {2, 3}, {3, 4}, {1, 4}, {4, 5}};
        for (int[] e : edges) adj.get(e[0]).add(e[1]);

        System.out.println("DAG adjacency list (prerequisite -> dependent):");
        for (int i = 0; i < n; i++) System.out.println("  " + i + " -> " + adj.get(i));

        List<Integer> order = topologicalSort(adj);
        if (order.isEmpty()) {
            System.out.println("Graph has a cycle -- no topological order exists.");
        } else {
            System.out.println("A valid topological order: " + order);
        }
    }
}
