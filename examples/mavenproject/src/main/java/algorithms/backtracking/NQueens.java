/**
 * N-QUEENS (BACKTRACKING)
 * --------------------------
 * The N-Queens problem asks for a placement of N queens on an N x N
 * chessboard so that no two queens attack each other (no shared row, column,
 * or diagonal). Since each row can only hold one queen without a column
 * conflict already being possible, we place exactly one queen per row and
 * choose which column it goes in.
 *
 * Core idea (backtrack-and-undo): we try columns for row 0, 1, 2, ... in
 * order. For the current row, we try each column: if placing a queen there
 * doesn't conflict with any queen already placed in an earlier row (checked
 * via a column-usage array and two diagonal-usage arrays, since all cells on
 * the same diagonal share either (row - col) or (row + col)), we place it,
 * recurse into the next row, and if that recursive attempt fails to complete
 * the board we "undo" the placement (unmark the column/diagonals) and try the
 * next column -- this undo step is exactly what makes it backtracking rather
 * than a plain greedy search: we explore a choice, and if it leads to a dead
 * end, we roll back state and try a different choice at the same decision
 * point. The search stops as soon as all N rows are filled consistently.
 *
 * Complexity (n = board size):
 *   - Worst case time is roughly O(n!) since each row tried narrows down
 *     candidate columns, but pruning via the conflict checks makes it much
 *     faster in practice than brute force O(n^n).
 *   - Space: O(n) for the column/diagonal tracking arrays plus O(n) recursion
 *     depth, i.e. O(n) auxiliary space (not counting the output board).
 */
public class NQueens {

    private final int n;
    private final int[] queenCol; // queenCol[row] = column of the queen in that row
    private final boolean[] colUsed;
    private final boolean[] diag1Used; // row - col + (n-1), always >= 0
    private final boolean[] diag2Used; // row + col

    public NQueens(int n) {
        this.n = n;
        this.queenCol = new int[n];
        this.colUsed = new boolean[n];
        this.diag1Used = new boolean[2 * n - 1];
        this.diag2Used = new boolean[2 * n - 1];
    }

    public boolean solve() {
        return place(0);
    }

    private boolean place(int row) {
        if (row == n) return true; // all rows filled consistently

        for (int col = 0; col < n; col++) {
            int d1 = row - col + (n - 1);
            int d2 = row + col;
            if (colUsed[col] || diag1Used[d1] || diag2Used[d2]) continue;

            // Choose: place the queen.
            queenCol[row] = col;
            colUsed[col] = diag1Used[d1] = diag2Used[d2] = true;

            if (place(row + 1)) return true; // explore

            // Undo the placement (backtrack) and try the next column.
            colUsed[col] = diag1Used[d1] = diag2Used[d2] = false;
        }
        return false; // no column worked for this row
    }

    public void printBoard() {
        for (int row = 0; row < n; row++) {
            StringBuilder sb = new StringBuilder();
            for (int col = 0; col < n; col++) {
                sb.append(queenCol[row] == col ? 'Q' : '.').append(' ');
            }
            System.out.println(sb.toString().trim());
        }
    }

    public static void main(String[] args) {
        int n = 8;
        NQueens solver = new NQueens(n);
        boolean found = solver.solve();

        System.out.println("Solving " + n + "-Queens...");
        if (found) {
            System.out.println("Solution found:");
            solver.printBoard();
        } else {
            System.out.println("No solution exists for n=" + n);
        }
    }
}
