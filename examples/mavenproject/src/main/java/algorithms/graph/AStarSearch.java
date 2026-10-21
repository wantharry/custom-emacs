import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.PriorityQueue;

/**
 * A* (A-STAR) SEARCH ALGORITHM
 *
 * What it does:
 *   Finds the shortest path between a start and a goal vertex in a
 *   weighted graph, typically faster in practice than Dijkstra because it
 *   uses a heuristic to focus the search toward the goal instead of
 *   expanding equally in every direction.
 *
 * Core idea / how it works:
 *   Like Dijkstra, but instead of ordering the priority queue purely by
 *   the known cost-so-far g(v), it orders by f(v) = g(v) + h(v), where
 *   h(v) is a heuristic ESTIMATE of the remaining distance from v to the
 *   goal (for grid/geometric graphs, straight-line distance is a common
 *   admissible heuristic). As long as h never OVER-estimates the true
 *   remaining distance ("admissible"), A* is guaranteed to still find the
 *   optimal path, while exploring far fewer irrelevant vertices than
 *   plain Dijkstra because the heuristic steers the frontier toward the goal.
 *
 * Time complexity:  O(E log V) worst case (same bound as Dijkstra), but in
 *                    practice visits far fewer vertices with a good heuristic.
 * Space complexity: O(V + E)   -- adjacency list, g-score map, and the heap.
 */
public class AStarSearch {

    /** A simple 2D point used both as a graph vertex id and for heuristic distance. */
    static class Point {
        final int id;
        final double x, y;
        Point(int id, double x, double y) { this.id = id; this.x = x; this.y = y; }
    }

    private static double heuristic(Point a, Point b) {
        double dx = a.x - b.x, dy = a.y - b.y;
        return Math.sqrt(dx * dx + dy * dy); // straight-line (Euclidean) estimate
    }

    /** adj.get(u) = list of int[]{neighbor, weight}. Returns the path as a list of vertex ids, or empty if unreachable. */
    public static List<Integer> aStar(List<List<int[]>> adj, Point[] points, int start, int goal) {
        int n = adj.size();
        double[] gScore = new double[n];
        java.util.Arrays.fill(gScore, Double.MAX_VALUE);
        gScore[start] = 0;
        Map<Integer, Integer> cameFrom = new HashMap<>();

        PriorityQueue<double[]> open = new PriorityQueue<>((a, b) -> Double.compare(a[1], b[1]));
        open.add(new double[]{start, heuristic(points[start], points[goal])});
        boolean[] closed = new boolean[n];

        while (!open.isEmpty()) {
            int u = (int) open.poll()[0];
            if (u == goal) break;
            if (closed[u]) continue;
            closed[u] = true;

            for (int[] edge : adj.get(u)) {
                int v = edge[0];
                double tentativeG = gScore[u] + edge[1];
                if (tentativeG < gScore[v]) {
                    gScore[v] = tentativeG;
                    cameFrom.put(v, u);
                    double f = tentativeG + heuristic(points[v], points[goal]);
                    open.add(new double[]{v, f});
                }
            }
        }

        if (gScore[goal] == Double.MAX_VALUE) return new ArrayList<>();

        List<Integer> path = new ArrayList<>();
        int cur = goal;
        path.add(cur);
        while (cur != start) {
            cur = cameFrom.get(cur);
            path.add(cur);
        }
        java.util.Collections.reverse(path);
        return path;
    }

    public static void main(String[] args) {
        // 7 points laid out roughly on a grid, with weighted edges roughly matching distance.
        Point[] points = {
            new Point(0, 0, 0), new Point(1, 1, 2), new Point(2, 2, 0),
            new Point(3, 3, 2), new Point(4, 4, 0), new Point(5, 2, 4), new Point(6, 5, 1)
        };
        int n = points.length;
        List<List<int[]>> adj = new ArrayList<>();
        for (int i = 0; i < n; i++) adj.add(new ArrayList<>());

        int[][] edges = {{0, 1, 2}, {1, 2, 3}, {2, 3, 3}, {3, 4, 3}, {0, 5, 5}, {5, 6, 4}, {6, 4, 2}, {1, 5, 4}};
        for (int[] e : edges) {
            adj.get(e[0]).add(new int[]{e[1], e[2]});
            adj.get(e[1]).add(new int[]{e[0], e[2]});
        }

        System.out.println("Points (id, x, y):");
        for (Point p : points) System.out.println("  " + p.id + ": (" + p.x + ", " + p.y + ")");

        int start = 0, goal = 4;
        List<Integer> path = aStar(adj, points, start, goal);
        System.out.println("A* path from " + start + " to " + goal + ": " + path);
    }
}
