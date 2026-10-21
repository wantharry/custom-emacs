/**
 * WORD SEARCH (BACKTRACKING)
 * -------------------------------
 * Given a 2D grid of letters and a target word, determine whether the word
 * can be formed by a path of adjacent cells (up/down/left/right, not
 * diagonally), using each cell at most once per path.
 *
 * Core idea (backtrack-and-undo): try every cell in the grid as a possible
 * starting point for the word's first letter. From a matching cell, "choose"
 * it by temporarily marking it visited (so the same cell can't be reused
 * later in the same path), then "explore" each of its four neighbors looking
 * for the next letter of the word, recursing with the next letter index. If
 * none of the neighbors continue the word successfully, we "undo" the mark
 * (unvisit the cell) so it becomes available again for a different path
 * attempt (e.g. a different starting cell might walk back through here), and
 * report failure to the caller. The recursion succeeds immediately once the
 * last letter of the word is matched.
 *
 * Complexity (rows*cols = grid size, L = word length):
 *   - Time: O(rows * cols * 4^L) in the worst case -- we may try every cell
 *     as a start, and from each, follow up to 4 directions at each of the L
 *     steps. In practice most branches are pruned immediately on a letter
 *     mismatch.
 *   - Space: O(L) for the recursion depth (the visited marks are stored
 *     in-place on the grid and undone, so no separate O(rows*cols) grid is
 *     needed).
 */
public class WordSearch {

    private final char[][] grid;
    private final int rows, cols;
    private static final int[] DR = {1, -1, 0, 0};
    private static final int[] DC = {0, 0, 1, -1};

    public WordSearch(char[][] grid) {
        this.grid = grid;
        this.rows = grid.length;
        this.cols = grid[0].length;
    }

    public boolean exists(String word) {
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (dfs(r, c, word, 0)) return true;
            }
        }
        return false;
    }

    private boolean dfs(int r, int c, String word, int idx) {
        if (idx == word.length()) return true;
        if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
        if (grid[r][c] != word.charAt(idx)) return false;

        char original = grid[r][c];
        grid[r][c] = '#'; // choose: mark visited so this path can't reuse it

        for (int dir = 0; dir < 4; dir++) {
            if (dfs(r + DR[dir], c + DC[dir], word, idx + 1)) { // explore
                grid[r][c] = original; // restore before returning
                return true;
            }
        }

        grid[r][c] = original; // undo (backtrack)
        return false;
    }

    public static void main(String[] args) {
        char[][] board = {
            {'A', 'B', 'C', 'E'},
            {'S', 'F', 'C', 'S'},
            {'A', 'D', 'E', 'E'}
        };

        WordSearch search = new WordSearch(board);

        String[] wordsToTest = {"ABCCED", "SEE", "ABCB", "ASADF"};
        for (String word : wordsToTest) {
            System.out.println("exists(\"" + word + "\"): " + search.exists(word));
        }
    }
}
