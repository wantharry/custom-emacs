/**
 * HAMILTONIAN PATH (BACKTRACKING)
 * -------------------------------------
 * A Hamiltonian path in a graph is a path that visits every vertex exactly
 * once (no repeats, not necessarily returning to the start). This file finds
 * one, starting from vertex 0, in a graph given as an adjacency matrix.
 *
 * Core idea (backtrack-and-undo): we build the path vertex by vertex. At each
 * step we "choose" an unvisited neighbor of the current last vertex in the
 * path, append it to the path, and mark it visited. We "explore" by
 * recursing to extend the path further. If the path ever reaches length
 * equal to the number of vertices, every vertex has been visited exactly
 * once and we have a complete Hamiltonian path. If no unvisited neighbor
 * leads to a complete path from here, we "undo" -- remove the last vertex
 * from the path and mark it unvisited again -- so an earlier step can try a
 * different neighbor instead. This undo is essential: without it, a vertex
 * that turned out to be a dead end would stay permanently marked visited and
 * block every other path attempt that might have used it.
 *
 * Complexity (V = number of vertices):
 *   - Worst-case time is O(V!) since in the worst case (a near-complete
 *     graph) we may need to try most orderings of vertices, though the
 *     visited-check and adjacency check prune invalid branches immediately.
 *   - Space: O(V) for the path and visited array, plus O(V) recursion depth.
 */
public class HamiltonianPath {

    private final boolean[][] adj;
    private final int v;
    private final int[] path;
    private final boolean[] visited;

    public HamiltonianPath(boolean[][] adjacencyMatrix) {
        this.adj = adjacencyMatrix;
        this.v = adjacencyMatrix.length;
        this.path = new int[v];
        this.visited = new boolean[v];
    }

    public int[] findPath() {
        path[0] = 0;
        visited[0] = true; // choose: start at vertex 0
        if (go(1)) return path;
        return null;
    }

    private boolean go(int position) {
        if (position == v) return true; // every vertex placed exactly once

        int last = path[position - 1];
        for (int next = 0; next < v; next++) {
            if (adj[last][next] && !visited[next]) {
                path[position] = next;   // choose
                visited[next] = true;
                if (go(position + 1)) return true; // explore
                visited[next] = false;   // undo (backtrack)
            }
        }
        return false;
    }

    public static void main(String[] args) {
        // Graph with a known Hamiltonian path: 0-1-2-3-4
        int n = 5;
        boolean[][] adj = new boolean[n][n];
        int[][] edges = {{0, 1}, {1, 2}, {2, 3}, {3, 4}, {0, 2}, {1, 3}};
        for (int[] e : edges) {
            adj[e[0]][e[1]] = true;
            adj[e[1]][e[0]] = true;
        }

        HamiltonianPath solver = new HamiltonianPath(adj);
        int[] path = solver.findPath();

        if (path != null) {
            System.out.println("Hamiltonian path found: " + java.util.Arrays.toString(path));
        } else {
            System.out.println("No Hamiltonian path exists starting from vertex 0.");
        }

        // Now a graph with no Hamiltonian path: vertex 4 is isolated.
        boolean[][] adjNoPath = new boolean[n][n];
        int[][] edges2 = {{0, 1}, {1, 2}, {2, 3}};
        for (int[] e : edges2) {
            adjNoPath[e[0]][e[1]] = true;
            adjNoPath[e[1]][e[0]] = true;
        }
        HamiltonianPath solver2 = new HamiltonianPath(adjNoPath);
        int[] path2 = solver2.findPath();
        System.out.println("Second graph (vertex 4 isolated) has a Hamiltonian path: " + (path2 != null));
    }
}
