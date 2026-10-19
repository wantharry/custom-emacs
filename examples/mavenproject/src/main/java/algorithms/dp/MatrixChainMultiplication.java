/**
 * MATRIX CHAIN MULTIPLICATION -- DYNAMIC PROGRAMMING
 *
 * Problem: given a chain of matrices A1, A2, ..., An with known
 * dimensions, matrix multiplication is associative, so the chain can be
 * parenthesized in many different ways, each requiring a different
 * number of scalar multiplications to fully evaluate. Find the
 * parenthesization (just the minimum cost here) that minimizes the total
 * number of scalar multiplications.
 *
 * Setup: dimensions are given as an array p[] of length n+1, where
 * matrix Ai has dimensions p[i-1] x p[i]. Multiplying a (p x q) matrix by
 * a (q x r) matrix costs p*q*r scalar multiplications and produces a
 * (p x r) matrix.
 *
 * Core idea (recurrence relation): let dp[i][j] be the minimum cost to
 * multiply the sub-chain of matrices Ai..Aj into a single matrix. If the
 * chain has only one matrix (i == j), no multiplication is needed:
 * dp[i][i] = 0. Otherwise, the LAST multiplication performed must split
 * the chain at some point k (i <= k < j) into (Ai..Ak) and (Ak+1..Aj),
 * each first reduced to a single matrix, then multiplied together:
 *   dp[i][j] = min over all split points k of
 *       dp[i][k] + dp[k+1][j] + p[i-1] * p[k] * p[j]
 * We try every possible split point k and keep the cheapest, because we
 * don't know in advance which split minimizes cost -- this is the
 * defining feature of the "interval DP" pattern, where we build up
 * answers for larger and larger sub-chains from answers on shorter ones.
 *
 * We fill the table by increasing chain length (gap between i and j),
 * since dp[i][j] depends only on sub-chains strictly shorter than itself.
 *
 * Time complexity: O(n^3) -- O(n^2) sub-chains, each trying O(n) split
 * points.
 * Space complexity: O(n^2) for the dp table.
 */
public class MatrixChainMultiplication {

    public static int minMultiplicationCost(int[] p) {
        int n = p.length - 1; // number of matrices
        int[][] dp = new int[n + 1][n + 1];

        // length = size of the sub-chain (number of matrices in it)
        for (int length = 2; length <= n; length++) {
            for (int i = 1; i <= n - length + 1; i++) {
                int j = i + length - 1;
                dp[i][j] = Integer.MAX_VALUE;
                for (int k = i; k < j; k++) {
                    int cost = dp[i][k] + dp[k + 1][j] + p[i - 1] * p[k] * p[j];
                    if (cost < dp[i][j]) {
                        dp[i][j] = cost;
                    }
                }
            }
        }
        return dp[1][n];
    }

    public static void main(String[] args) {
        // Chain of 4 matrices: A1 (10x20), A2 (20x30), A3 (30x40), A4 (40x30)
        // p[] encodes dimensions: matrix i has dims p[i-1] x p[i]
        int[] p = {10, 20, 30, 40, 30};

        System.out.println("Matrix Chain Multiplication");
        System.out.println("Matrix dimension chain (p): consecutive pairs give each matrix's shape");
        for (int i = 0; i < p.length - 1; i++) {
            System.out.println("Matrix A" + (i + 1) + ": " + p[i] + " x " + p[i + 1]);
        }

        int result = minMultiplicationCost(p);
        System.out.println();
        System.out.println("Final computed answer -> Minimum scalar multiplications: " + result);
    }
}
