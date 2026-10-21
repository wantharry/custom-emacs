import java.util.ArrayList;
import java.util.List;

/**
 * PRIME FACTORIZATION (Trial Division)
 *
 * What it does:
 *   Decomposes a positive integer into the product of its prime factors
 *   (with repetition), e.g. 360 = 2 * 2 * 2 * 3 * 3 * 5.
 *
 * Core idea / how it works:
 *   Repeatedly divide the number by the smallest possible factor. Start
 *   with 2: while the number is still divisible by 2, divide it out and
 *   record a factor of 2 -- this strips all factors of 2 at once. Then
 *   try 3, 5, 7, 9, ... (odd candidates only, since all factors of 2 are
 *   already gone) up to sqrt(remaining number); whenever a candidate
 *   divides evenly, keep dividing it out and recording it before moving
 *   to the next candidate. Stop increasing the candidate once candidate^2
 *   exceeds what's left -- if anything greater than 1 remains at that
 *   point, that leftover value is itself a prime factor (it has no
 *   smaller factor, by the same sqrt argument used in primality testing).
 *
 * Time complexity:  O(sqrt(n))  -- trial division up to the square root.
 * Space complexity: O(log n)    -- at most log2(n) factors can be found.
 */
public class PrimeFactorization {

    public static List<Long> factorize(long n) {
        List<Long> factors = new ArrayList<>();
        if (n < 2) return factors;

        while (n % 2 == 0) {
            factors.add(2L);
            n /= 2;
        }
        for (long candidate = 3; candidate * candidate <= n; candidate += 2) {
            while (n % candidate == 0) {
                factors.add(candidate);
                n /= candidate;
            }
        }
        if (n > 1) {
            factors.add(n); // whatever remains is itself prime
        }
        return factors;
    }

    public static void main(String[] args) {
        long[] candidates = {360, 97, 100, 1, 2310, 999999};
        System.out.println("Prime factorization:");
        for (long n : candidates) {
            List<Long> factors = factorize(n);
            System.out.println("  " + n + " = " + factors);
        }
    }
}
