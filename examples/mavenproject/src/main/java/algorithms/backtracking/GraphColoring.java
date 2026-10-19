/**
 * GRAPH COLORING (M-COLORING, BACKTRACKING)
 * ------------------------------------------------
 * Given a graph and a number of colors m, determine whether the vertices can
 * be colored using at most m colors so that no two adjacent vertices share
 * the same color, and if so, produce a valid coloring.
 *
 * Core idea (backtrack-and-undo): we assign colors to vertices one at a time,
 * in order 0, 1, 2, ... At vertex v, we try each color from 1 to m: a color
 * is valid for v only if none of v's already-colored neighbors use that same
 * color. If a color is valid, we "choose" it (assign it to v) and "explore"
 * by recursing to color the next vertex. If that recursive attempt
 * eventually colors every vertex successfully, we're done. If it fails for
 * every remaining vertex down that branch, we "undo" the assignment (reset
 * v's color to uncolored) and try the next color for v -- the backtracking
 * step that lets a different color choice be explored instead. If no color
 * works for v, we report failure so an earlier vertex can backtrack too.
 *
 * Complexity (V = vertices, m = number of colors):
 *   - Worst-case time is O(m^V) since each of the V vertices could try up to
 *     m colors, though adjacency checks prune invalid branches immediately.
 *   - Space: O(V) for the color assignment array, plus O(V) recursion depth.
 */
public class GraphColoring {

    private final boolean[][] adj;
    private final int v;
    private final int m;
    private final int[] colors; // colors[i] = color assigned to vertex i (0 = uncolored)

    public GraphColoring(boolean[][] adjacencyMatrix, int numColors) {
        this.adj = adjacencyMatrix;
        this.v = adjacencyMatrix.length;
        this.m = numColors;
        this.colors = new int[v];
    }

    public boolean solve() {
        return colorVertex(0);
    }

    private boolean colorVertex(int vertex) {
        if (vertex == v) return true; // all vertices colored

        for (int color = 1; color <= m; color++) {
            if (isSafe(vertex, color)) {
                colors[vertex] = color;          // choose
                if (colorVertex(vertex + 1)) return true; // explore
                colors[vertex] = 0;               // undo (backtrack)
            }
        }
        return false;
    }

    private boolean isSafe(int vertex, int color) {
        for (int other = 0; other < v; other++) {
            if (adj[vertex][other] && colors[other] == color) return false;
        }
        return true;
    }

    public int[] getColors() {
        return colors;
    }

    public static void main(String[] args) {
        // A square with both diagonals (K4 minus nothing extra): needs the
        // standard 4-vertex fully-connected-ish graph below to require 3 colors.
        int n = 4;
        boolean[][] adj = new boolean[n][n];
        int[][] edges = {{0, 1}, {1, 2}, {2, 3}, {3, 0}, {0, 2}};
        for (int[] e : edges) {
            adj[e[0]][e[1]] = true;
            adj[e[1]][e[0]] = true;
        }

        System.out.println("Trying with 2 colors:");
        GraphColoring with2 = new GraphColoring(adj, 2);
        System.out.println("Possible: " + with2.solve());

        System.out.println("Trying with 3 colors:");
        GraphColoring with3 = new GraphColoring(adj, 3);
        boolean possible = with3.solve();
        System.out.println("Possible: " + possible);
        if (possible) {
            System.out.println("Coloring (vertex -> color): " + java.util.Arrays.toString(with3.getColors()));
        }
    }
}
