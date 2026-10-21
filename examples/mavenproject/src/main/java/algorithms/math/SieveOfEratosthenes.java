import java.util.ArrayList;
import java.util.List;

/**
 * SIEVE OF ERATOSTHENES
 *
 * What it does:
 *   Finds every prime number up to a given limit N, all at once, far
 *   faster than testing each number individually for primality.
 *
 * Core idea / how it works:
 *   Start by assuming every number from 2 to N is prime. Walk through
 *   numbers starting at 2: whenever a number p is still marked prime,
 *   it truly is prime (nothing smaller has crossed it out), so mark every
 *   MULTIPLE of p (2p, 3p, 4p, ...) as composite, since they can never be
 *   prime. Move to the next unmarked number and repeat. You only need to
 *   start sieving multiples from p*p (smaller multiples of p were already
 *   crossed out by smaller primes), and you only need to check p up to
 *   sqrt(N), since any composite <= N has a factor <= sqrt(N).
 *
 * Time complexity:  O(N log log N)  -- the sum of N/p over all primes p <= N.
 * Space complexity: O(N)            -- the boolean "is composite" array.
 */
public class SieveOfEratosthenes {

    public static List<Integer> sieve(int limit) {
        boolean[] isComposite = new boolean[limit + 1];
        List<Integer> primes = new ArrayList<>();

        for (int p = 2; p <= limit; p++) {
            if (!isComposite[p]) {
                primes.add(p);
                for (long multiple = (long) p * p; multiple <= limit; multiple += p) {
                    isComposite[(int) multiple] = true;
                }
            }
        }
        return primes;
    }

    public static void main(String[] args) {
        int limit = 100;
        List<Integer> primes = sieve(limit);
        System.out.println("All primes up to " + limit + " (" + primes.size() + " found):");
        System.out.println("  " + primes);
    }
}
