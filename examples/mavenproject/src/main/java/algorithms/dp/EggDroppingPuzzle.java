/**
 * EGG DROPPING PUZZLE -- DYNAMIC PROGRAMMING
 *
 * Problem: given k eggs and a building with n floors, find the minimum
 * number of trial drops needed, IN THE WORST CASE, to determine the
 * exact critical floor from which an egg breaks when dropped (eggs break
 * the same way from that floor and above, and survive all drops below
 * it; a surviving egg can be reused, a broken one cannot).
 *
 * Core idea (recurrence relation): let dp[eggs][floors] be the minimum
 * number of trials needed to guarantee finding the critical floor among
 * `floors` floors using at most `eggs` eggs. Suppose we drop an egg from
 * some floor x (1 <= x <= floors). Two outcomes are possible:
 *   - The egg breaks: the critical floor is at or below x, so we now
 *     have (eggs - 1) eggs and only need to search the (x - 1) floors
 *     below x: dp[eggs-1][x-1] more trials.
 *   - The egg survives: the critical floor is above x, so we still have
 *     `eggs` eggs and need to search the (floors - x) floors above x:
 *     dp[eggs][floors-x] more trials.
 * Since we must guarantee success in the WORST case, dropping from floor
 * x costs 1 (for this drop) plus the WORSE of the two outcomes:
 *   cost(x) = 1 + max( dp[eggs-1][x-1], dp[eggs][floors-x] )
 * We get to pick which floor x to try, so we choose the one that
 * minimizes this worst case:
 *   dp[eggs][floors] = min over x in [1, floors] of cost(x)
 * Base cases: dp[1][floors] = floors (with only 1 egg, you must test
 * every floor one by one from the bottom, no shortcuts allowed since a
 * break means you're out of eggs); dp[eggs][0] = 0 (no floors to check
 * means no trials needed).
 *
 * Time complexity: O(k * n^2) with the straightforward table fill shown
 * here (trying every floor x for every (eggs, floors) pair). This can be
 * optimized to O(k * n log n) with binary search on x, since cost(x) is
 * monotonic, but the O(k*n^2) version is the clearest illustration of
 * the recurrence.
 * Space complexity: O(k * n) for the dp table.
 */
public class EggDroppingPuzzle {

    public static int minTrials(int eggs, int floors) {
        int[][] dp = new int[eggs + 1][floors + 1];

        // Base case: 1 egg -> must try every floor one at a time.
        for (int f = 0; f <= floors; f++) {
            dp[1][f] = f;
        }
        // Base case: 0 floors -> 0 trials needed, for any number of eggs.
        for (int e = 1; e <= eggs; e++) {
            dp[e][0] = 0;
            dp[e][1] = 1; // with >=1 floor and >=1 egg, 1 floor always needs exactly 1 trial
        }

        for (int e = 2; e <= eggs; e++) {
            for (int f = 2; f <= floors; f++) {
                int best = Integer.MAX_VALUE;
                for (int x = 1; x <= f; x++) {
                    int breakCase = dp[e - 1][x - 1];
                    int surviveCase = dp[e][f - x];
                    int worst = 1 + Math.max(breakCase, surviveCase);
                    if (worst < best) {
                        best = worst;
                    }
                }
                dp[e][f] = best;
            }
        }
        return dp[eggs][floors];
    }

    public static void main(String[] args) {
        int eggs = 2;
        int floors = 10;

        System.out.println("Egg Dropping Puzzle");
        System.out.println("Number of eggs: " + eggs);
        System.out.println("Number of floors: " + floors);

        int result = minTrials(eggs, floors);
        System.out.println();
        System.out.println("Final computed answer -> Minimum trials needed in the worst case: " + result);
    }
}
