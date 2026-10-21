/**
 * KNIGHT'S TOUR (BACKTRACKING)
 * ----------------------------------
 * The Knight's Tour problem asks for a sequence of knight moves on an N x N
 * chessboard that visits every square exactly once, starting from a given
 * square. A knight moves in an L-shape: 2 squares in one direction and 1
 * square perpendicular to that, giving up to 8 possible moves from any
 * square.
 *
 * Core idea (backtrack-and-undo): we track which squares have been visited
 * and in what order. From the current square, we try each of the 8 possible
 * knight moves, in a fixed order; a move is only tried if the destination
 * square is on the board and not yet visited. We "choose" a valid move by
 * marking the destination visited and recording its visit order, then
 * "explore" by recursing from there. If the recursion eventually visits all
 * N*N squares, the tour is complete. If a branch dead-ends before that (no
 * valid move available, but squares remain unvisited), we "undo" the move --
 * unmark the destination as visited -- and try the next of the 8 move
 * directions from the current square instead. This systematic try/undo over
 * all 8 directions at every square is what lets the search recover from a
 * dead end instead of getting stuck.
 *
 * Complexity (n = board dimension, so n^2 squares):
 *   - Worst-case time is exponential, bounded by O(8^(n^2)) without
 *     heuristics, since each of the n^2 squares could try up to 8 moves; the
 *     visited check prunes revisits, and for modest board sizes (e.g. 5x5,
 *     6x6) a plain backtracking search like this still completes quickly.
 *   - Space: O(n^2) for the board/visit-order tracking, plus O(n^2) recursion
 *     depth in the worst case.
 */
public class KnightsTour {

    private final int n;
    private final int[][] board; // board[r][c] = move number (0-based) at which (r,c) was visited, -1 if unvisited
    private static final int[] DR = {2, 1, -1, -2, -2, -1, 1, 2};
    private static final int[] DC = {1, 2, 2, 1, -1, -2, -2, -1};

    public KnightsTour(int n) {
        this.n = n;
        this.board = new int[n][n];
        for (int[] row : board) java.util.Arrays.fill(row, -1);
    }

    public boolean solve(int startRow, int startCol) {
        board[startRow][startCol] = 0; // choose: visit the start square first
        return move(startRow, startCol, 1);
    }

    private boolean move(int row, int col, int moveCount) {
        if (moveCount == n * n) return true; // every square visited

        for (int dir = 0; dir < 8; dir++) {
            int nr = row + DR[dir];
            int nc = col + DC[dir];
            if (isValid(nr, nc)) {
                board[nr][nc] = moveCount; // choose
                if (move(nr, nc, moveCount + 1)) return true; // explore
                board[nr][nc] = -1; // undo (backtrack)
            }
        }
        return false;
    }

    private boolean isValid(int r, int c) {
        return r >= 0 && r < n && c >= 0 && c < n && board[r][c] == -1;
    }

    public void printBoard() {
        for (int[] row : board) {
            StringBuilder sb = new StringBuilder();
            for (int val : row) sb.append(String.format("%3d", val));
            System.out.println(sb.toString());
        }
    }

    public static void main(String[] args) {
        int n = 5;
        KnightsTour tour = new KnightsTour(n);
        boolean found = tour.solve(0, 0);

        System.out.println("Knight's Tour on " + n + "x" + n + " board starting at (0,0):");
        if (found) {
            System.out.println("Full tour found. Move numbers (0-based) for each square:");
            tour.printBoard();
        } else {
            System.out.println("No complete tour found from this starting square.");
        }
    }
}
