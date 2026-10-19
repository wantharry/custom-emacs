import java.util.ArrayList;
import java.util.List;

/**
 * PASCAL'S TRIANGLE
 *
 * What it does:
 *   Builds the triangular array of binomial coefficients, where row r,
 *   column c holds C(r, c) -- the number of ways to choose c items from
 *   r. Used in combinatorics, binomial expansion ((x+y)^n coefficients),
 *   and probability (e.g. counting coin-flip outcomes).
 *
 * Core idea / how it works:
 *   Each row is built from the row above it using the Pascal recurrence
 *   C(r, c) = C(r-1, c-1) + C(r-1, c), with the edges of every row fixed
 *   at 1 (there's exactly one way to choose 0 items, and exactly one way
 *   to choose all of them). So row 0 is just [1]; to build row r, start
 *   and end each row with 1, and every interior entry is the sum of the
 *   two entries diagonally above it in the previous row. This avoids ever
 *   computing a factorial directly -- the triangle is built purely with
 *   additions.
 *
 * Time complexity:  O(n^2)  -- n rows, each with up to n entries.
 * Space complexity: O(n^2)  -- storing the whole triangle (O(n) if only the last row is kept).
 */
public class PascalsTriangle {

    public static List<List<Long>> generate(int numRows) {
        List<List<Long>> triangle = new ArrayList<>();
        for (int r = 0; r < numRows; r++) {
            List<Long> row = new ArrayList<>();
            for (int c = 0; c <= r; c++) {
                if (c == 0 || c == r) {
                    row.add(1L);
                } else {
                    row.add(triangle.get(r - 1).get(c - 1) + triangle.get(r - 1).get(c));
                }
            }
            triangle.add(row);
        }
        return triangle;
    }

    public static void main(String[] args) {
        int numRows = 10;
        List<List<Long>> triangle = generate(numRows);
        System.out.println("Pascal's Triangle, " + numRows + " rows:");
        for (List<Long> row : triangle) {
            System.out.println("  " + row);
        }
    }
}
