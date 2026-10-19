/**
 * RAT IN A MAZE (BACKTRACKING)
 * --------------------------------
 * Given an N x N maze of open (1) and blocked (0) cells, find a path for a rat
 * from the top-left cell to the bottom-right cell, moving only through open
 * cells, using moves down, right, up, and left.
 *
 * Core idea (backtrack-and-undo): starting at (0, 0), we mark the current
 * cell as part of the path ("choose") and try moving to each neighboring
 * cell, in a fixed order (down, right, up, left), but only if that neighbor
 * is inside the grid, open, and not already visited on the current path. We
 * recurse into that neighbor ("explore"). If the recursive call eventually
 * reaches the destination, success propagates all the way back up and we
 * stop. If a branch dead-ends (every neighbor from some cell fails), we
 * "undo" by unmarking the current cell as visited and unmarking it in the
 * output path, then return false so the caller tries a different neighbor --
 * this undo is what allows the same cell to be considered again as part of a
 * different candidate path, and is the core of backtracking search over a
 * maze.
 *
 * Complexity (n = grid dimension, so n^2 cells):
 *   - Worst-case time is exponential in the number of open cells (up to
 *     O(4^(n^2)) without pruning), but the visited-check prunes revisiting
 *     cells, and in practice mazes solve quickly since dead ends are detected
 *     immediately.
 *   - Space: O(n^2) for the visited/path tracking grids, plus O(n^2)
 *     recursion depth in the worst case.
 */
public class RatInAMaze {

    private final int[][] maze;
    private final int n;
    private final int[][] path; // 1 marks a cell that is part of the found path
    private final boolean[][] visited;

    private static final int[] DR = {1, 0, -1, 0}; // down, right(no change in row), up, left(no change)
    private static final int[] DC = {0, 1, 0, -1};

    public RatInAMaze(int[][] maze) {
        this.maze = maze;
        this.n = maze.length;
        this.path = new int[n][n];
        this.visited = new boolean[n][n];
    }

    public boolean solve() {
        if (maze[0][0] == 0) return false;
        return go(0, 0);
    }

    private boolean go(int row, int col) {
        if (row == n - 1 && col == n - 1) {
            path[row][col] = 1;
            return true;
        }

        visited[row][col] = true;
        path[row][col] = 1; // choose

        for (int dir = 0; dir < 4; dir++) {
            int nr = row + DR[dir];
            int nc = col + DC[dir];
            if (isValid(nr, nc)) {
                if (go(nr, nc)) return true; // explore
            }
        }

        path[row][col] = 0;     // undo (backtrack)
        visited[row][col] = false;
        return false;
    }

    private boolean isValid(int r, int c) {
        return r >= 0 && r < n && c >= 0 && c < n
                && maze[r][c] == 1 && !visited[r][c];
    }

    public void printPath() {
        for (int[] row : path) {
            StringBuilder sb = new StringBuilder();
            for (int val : row) sb.append(val).append(' ');
            System.out.println(sb.toString().trim());
        }
    }

    public static void main(String[] args) {
        int[][] maze = {
            {1, 0, 0, 0},
            {1, 1, 0, 1},
            {0, 1, 0, 0},
            {1, 1, 1, 1}
        };

        RatInAMaze solver = new RatInAMaze(maze);
        boolean found = solver.solve();

        System.out.println("Maze:");
        for (int[] row : maze) System.out.println(java.util.Arrays.toString(row));

        System.out.println();
        if (found) {
            System.out.println("Path found (1 = on path):");
            solver.printPath();
        } else {
            System.out.println("No path exists from top-left to bottom-right.");
        }
    }
}
