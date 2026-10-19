/**
 * FLOYD-WARSHALL ALL-PAIRS SHORTEST PATH ALGORITHM
 *
 * What it does:
 *   Computes the shortest distance between EVERY pair of vertices in a
 *   weighted directed graph in one shot (handles negative edge weights,
 *   as long as there is no negative cycle).
 *
 * Core idea / how it works:
 *   Dynamic programming over "allowed intermediate vertices". Start with
 *   dist[i][j] = direct edge weight (or infinity if no edge). Then, for
 *   each vertex k from 0 to n-1 in turn, consider k as a possible
 *   intermediate stop: for every pair (i, j), check whether going
 *   i -> k -> j is shorter than the current best i -> j path that only
 *   used intermediates from {0, ..., k-1}. After k has been considered
 *   for all pairs, dist[i][j] holds the shortest path that may use any
 *   vertex in {0, ..., k} as an intermediate. After processing all k,
 *   dist[i][j] is the true shortest path using any intermediates at all.
 *
 * Time complexity:  O(V^3)  -- three nested loops over all vertices.
 * Space complexity: O(V^2)  -- the full distance matrix.
 */
public class FloydWarshall {

    private static final int INF = 1_000_000;

    /** matrix[i][j] is edge weight i->j, or INF if no direct edge (matrix[i][i] = 0). Modified in place. */
    public static int[][] floydWarshall(int[][] matrix) {
        int n = matrix.length;
        int[][] dist = new int[n][n];
        for (int i = 0; i < n; i++) dist[i] = matrix[i].clone();

        for (int k = 0; k < n; k++) {
            for (int i = 0; i < n; i++) {
                for (int j = 0; j < n; j++) {
                    if (dist[i][k] + dist[k][j] < dist[i][j]) {
                        dist[i][j] = dist[i][k] + dist[k][j];
                    }
                }
            }
        }
        return dist;
    }

    private static void printMatrix(int[][] m) {
        int n = m.length;
        for (int i = 0; i < n; i++) {
            StringBuilder sb = new StringBuilder("  ");
            for (int j = 0; j < n; j++) {
                sb.append(m[i][j] >= INF ? "INF" : String.valueOf(m[i][j])).append("\t");
            }
            System.out.println(sb);
        }
    }

    public static void main(String[] args) {
        // Directed graph, 5 nodes (0..4). matrix[i][j] = edge weight, INF if none, 0 on diagonal.
        int n = 5;
        int[][] matrix = new int[n][n];
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++) matrix[i][j] = (i == j) ? 0 : INF;
        }
        int[][] edges = {{0, 1, 3}, {0, 3, 7}, {1, 0, 8}, {1, 2, 2}, {2, 0, 5}, {3, 2, 1}, {3, 4, 2}, {4, 0, 2}};
        for (int[] e : edges) matrix[e[0]][e[1]] = e[2];

        System.out.println("Initial adjacency matrix (direct edges only):");
        printMatrix(matrix);

        int[][] result = floydWarshall(matrix);

        System.out.println("All-pairs shortest distances:");
        printMatrix(result);
    }
}
