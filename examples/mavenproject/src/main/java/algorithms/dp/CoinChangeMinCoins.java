/**
 * COIN CHANGE -- MINIMUM NUMBER OF COINS (DYNAMIC PROGRAMMING)
 *
 * Problem: given a set of coin denominations (each available in
 * unlimited supply) and a target amount, find the minimum number of
 * coins needed to make exactly that amount, or report that it is
 * impossible.
 *
 * Core idea (recurrence relation): let dp[x] be the minimum number of
 * coins needed to make amount x. For each amount x, try using one more
 * coin of every denomination c (where c <= x): if we use a coin of value
 * c, the remaining amount x - c must itself be made optimally, so the
 * candidate coin count is dp[x - c] + 1. We take the best (smallest)
 * candidate over all denominations:
 *   dp[x] = min over all coins c <= x of ( dp[x - c] + 1 )
 * Base case: dp[0] = 0 (zero coins needed to make amount 0). If no coin
 * can validly reach amount x (every dp[x-c] is "infinity", i.e.
 * unreachable), then dp[x] is also unreachable.
 *
 * This is an unbounded-choice DP: like unbounded knapsack, each coin
 * denomination may be reused any number of times, so we only need a 1D
 * array indexed by amount, not by (coin index, amount).
 *
 * Time complexity: O(amount * numCoins) -- for each amount from 1 to the
 * target we try every denomination.
 * Space complexity: O(amount) for the dp array.
 */
public class CoinChangeMinCoins {

    private static final int UNREACHABLE = Integer.MAX_VALUE / 2;

    public static int minCoins(int[] coins, int amount) {
        int[] dp = new int[amount + 1];
        for (int x = 1; x <= amount; x++) {
            dp[x] = UNREACHABLE;
            for (int coin : coins) {
                if (coin <= x && dp[x - coin] + 1 < dp[x]) {
                    dp[x] = dp[x - coin] + 1;
                }
            }
        }
        return dp[amount] >= UNREACHABLE ? -1 : dp[amount];
    }

    public static void main(String[] args) {
        int[] coins = {1, 3, 4};
        int amount = 6;

        System.out.println("Coin Change - Minimum Number of Coins");
        System.out.print("Denominations: ");
        for (int c : coins) {
            System.out.print(c + " ");
        }
        System.out.println();
        System.out.println("Target amount: " + amount);

        int result = minCoins(coins, amount);
        System.out.println();
        System.out.println("Final computed answer -> Minimum coins needed: " + result);

        int impossibleAmount = 2;
        int[] impossibleCoins = {5, 10};
        int check = minCoins(impossibleCoins, impossibleAmount);
        System.out.println("Sanity check with coins {5,10} for amount 2 (should be -1): " + check);
    }
}
