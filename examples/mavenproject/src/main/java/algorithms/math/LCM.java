/**
 * LEAST COMMON MULTIPLE (LCM)
 *
 * What it does:
 *   Computes the smallest positive integer that is evenly divisible by
 *   both of two given integers.
 *
 * Core idea / how it works:
 *   Uses the identity lcm(a, b) = |a * b| / gcd(a, b). The GCD is
 *   computed first with the Euclidean algorithm (repeatedly replacing
 *   (a, b) with (b, a mod b) until b is 0). Dividing the product by the
 *   GCD removes exactly the "double-counted" common factors, leaving the
 *   smallest common multiple. To avoid intermediate overflow on large
 *   inputs, the division by gcd is done BEFORE multiplying (a / gcd) * b.
 *
 * Time complexity:  O(log(min(a, b)))  -- dominated by the Euclidean GCD step.
 * Space complexity: O(1).
 */
public class LCM {

    private static long gcd(long a, long b) {
        a = Math.abs(a);
        b = Math.abs(b);
        while (b != 0) {
            long temp = b;
            b = a % b;
            a = temp;
        }
        return a;
    }

    public static long lcm(long a, long b) {
        if (a == 0 || b == 0) return 0;
        long g = gcd(a, b);
        return Math.abs(a / g * b);
    }

    public static void main(String[] args) {
        long[][] pairs = {{4, 6}, {21, 6}, {8, 9}, {15, 20}, {7, 7}};
        System.out.println("Computing LCM for several pairs:");
        for (long[] pair : pairs) {
            System.out.println("  lcm(" + pair[0] + ", " + pair[1] + ") = " + lcm(pair[0], pair[1]));
        }
    }
}
