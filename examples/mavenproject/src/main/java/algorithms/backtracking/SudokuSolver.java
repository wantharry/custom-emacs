/**
 * SUDOKU SOLVER (BACKTRACKING)
 * --------------------------------
 * Sudoku requires filling a 9x9 grid with digits 1-9 so that every row, every
 * column, and every 3x3 box contains each digit exactly once, while respecting
 * the digits already given as clues.
 *
 * Core idea (backtrack-and-undo): scan the grid for the next empty cell. Try
 * each digit 1-9 in that cell; a digit is only a valid try if it doesn't
 * already appear in the same row, column, or 3x3 box. If it's valid, place it
 * and recurse to solve the rest of the grid. If that recursive call succeeds,
 * we're done -- propagate success back up. If it fails (returns false,
 * meaning no digit works for some later empty cell), we undo the placement
 * (reset the cell back to empty) and try the next digit -- this undo is the
 * backtracking step. If every digit fails for the current cell, we return
 * false so the caller (an earlier cell) backtracks too. The recursion
 * bottoms out successfully when there are no more empty cells.
 *
 * Complexity (81 cells, 9 candidate digits each in the worst case):
 *   - Worst-case time is exponential, bounded by O(9^(number of empty cells)),
 *     but the row/column/box validity checks prune the vast majority of
 *     branches immediately, so real puzzles solve almost instantly.
 *   - Space: O(1) extra besides the 9x9 grid itself (the recursion depth is
 *     bounded by the number of empty cells, at most 81).
 */
public class SudokuSolver {

    private static final int SIZE = 9;
    private final int[][] grid;

    public SudokuSolver(int[][] grid) {
        this.grid = grid;
    }

    public boolean solve() {
        for (int row = 0; row < SIZE; row++) {
            for (int col = 0; col < SIZE; col++) {
                if (grid[row][col] == 0) {
                    for (int digit = 1; digit <= 9; digit++) {
                        if (isValid(row, col, digit)) {
                            grid[row][col] = digit; // choose
                            if (solve()) return true; // explore
                            grid[row][col] = 0; // undo (backtrack)
                        }
                    }
                    return false; // no digit worked here; backtrack further up
                }
            }
        }
        return true; // no empty cells left -- solved
    }

    private boolean isValid(int row, int col, int digit) {
        for (int i = 0; i < SIZE; i++) {
            if (grid[row][i] == digit) return false;
            if (grid[i][col] == digit) return false;
        }
        int boxRow = (row / 3) * 3;
        int boxCol = (col / 3) * 3;
        for (int r = boxRow; r < boxRow + 3; r++) {
            for (int c = boxCol; c < boxCol + 3; c++) {
                if (grid[r][c] == digit) return false;
            }
        }
        return true;
    }

    public void printGrid() {
        for (int[] row : grid) {
            StringBuilder sb = new StringBuilder();
            for (int val : row) sb.append(val).append(' ');
            System.out.println(sb.toString().trim());
        }
    }

    public static void main(String[] args) {
        int[][] puzzle = {
            {5, 3, 0, 0, 7, 0, 0, 0, 0},
            {6, 0, 0, 1, 9, 5, 0, 0, 0},
            {0, 9, 8, 0, 0, 0, 0, 6, 0},
            {8, 0, 0, 0, 6, 0, 0, 0, 3},
            {4, 0, 0, 8, 0, 3, 0, 0, 1},
            {7, 0, 0, 0, 2, 0, 0, 0, 6},
            {0, 6, 0, 0, 0, 0, 2, 8, 0},
            {0, 0, 0, 4, 1, 9, 0, 0, 5},
            {0, 0, 0, 0, 8, 0, 0, 7, 9}
        };

        SudokuSolver solver = new SudokuSolver(puzzle);
        System.out.println("Puzzle:");
        solver.printGrid();

        boolean solved = solver.solve();
        System.out.println();
        if (solved) {
            System.out.println("Solved:");
            solver.printGrid();
        } else {
            System.out.println("No solution exists for this puzzle.");
        }
    }
}
