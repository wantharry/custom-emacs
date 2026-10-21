/**
 * FACTORIAL (Recursive)
 *
 * What it does:
 *   Computes n! = n * (n-1) * (n-2) * ... * 1 (with 0! defined as 1),
 *   the number of ways to arrange n distinct items in order. It's a
 *   building block for combinatorics (permutations, combinations).
 *
 * Core idea / how it works:
 *   Direct translation of the mathematical recurrence n! = n * (n-1)!,
 *   with base case 0! = 1. The recursive call keeps reducing the problem
 *   to a smaller instance until it hits the base case, then the stack
 *   unwinds multiplying the results back together. This is the canonical
 *   example of recursion in computer science: a clean match between the
 *   mathematical definition and the code.
 *
 * Time complexity:  O(n)  -- n recursive multiplications.
 * Space complexity: O(n)  -- recursion call stack depth (each call holds
 *                            one frame until the base case returns).
 */
public class FactorialRecursive {

    public static long factorial(int n) {
        if (n < 0) throw new IllegalArgumentException("factorial is undefined for negative numbers");
        if (n == 0 || n == 1) return 1;
        return n * factorial(n - 1);
    }

    public static void main(String[] args) {
        int[] inputs = {0, 1, 5, 10, 15, 20};
        System.out.println("Computing factorials recursively:");
        for (int n : inputs) {
            System.out.println("  " + n + "! = " + factorial(n));
        }
    }
}
