/**
 * FAST MODULAR EXPONENTIATION (Binary Exponentiation)
 *
 * What it does:
 *   Computes (base^exponent) mod m efficiently, even when exponent is
 *   huge (e.g. millions) -- essential for cryptography (RSA), hashing,
 *   and competitive programming where naive repeated multiplication
 *   would be far too slow or overflow.
 *
 * Core idea / how it works:
 *   Based on repeated squaring: base^exponent can be broken down using
 *   the binary representation of exponent. If exponent is even,
 *   base^exponent = (base^(exponent/2))^2. If exponent is odd,
 *   base^exponent = base * base^(exponent-1). So the loop keeps squaring
 *   "base" (mod m, to keep numbers small) and halving "exponent"; every
 *   time the current lowest bit of exponent is 1, the current squared
 *   base is multiplied into the running result. This visits only
 *   O(log exponent) bits instead of doing "exponent" separate multiplications.
 *
 * Time complexity:  O(log exponent)  -- one squaring per bit of the exponent.
 * Space complexity: O(1).
 */
public class FastModularExponentiation {

    public static long modPow(long base, long exponent, long modulus) {
        if (modulus == 1) return 0;
        long result = 1;
        base = base % modulus;
        if (base < 0) base += modulus;

        while (exponent > 0) {
            if ((exponent & 1) == 1) {
                result = (result * base) % modulus;
            }
            base = (base * base) % modulus;
            exponent >>= 1;
        }
        return result;
    }

    public static void main(String[] args) {
        long[][] cases = {
            {2, 10, 1000},     // 1024 mod 1000 = 24
            {3, 200, 50},      // large exponent
            {7, 0, 13},        // anything^0 = 1
            {5, 117, 19},      // odd exponent
            {2, 1000000, 1000000007}
        };
        System.out.println("Computing (base^exponent) mod m:");
        for (long[] c : cases) {
            long base = c[0], exp = c[1], mod = c[2];
            System.out.println("  (" + base + "^" + exp + ") mod " + mod + " = " + modPow(base, exp, mod));
        }
    }
}
