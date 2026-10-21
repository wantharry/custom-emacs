/**
 * COIN CHANGE -- NUMBER OF WAYS TO MAKE AN AMOUNT (DYNAMIC PROGRAMMING)
 *
 * Problem: given a set of coin denominations (unlimited supply of each)
 * and a target amount, count the number of DISTINCT combinations of
 * coins that sum to exactly that amount. Order doesn't matter -- using
 * one 1-cent coin then a 3-cent coin counts the same as a 3-cent coin
 * then a 1-cent coin.
 *
 * Core idea (recurrence relation): let dp[x] be the number of ways to
 * make amount x using the coin denominations considered so far. To avoid
 * counting permutations of the same combination separately, we process
 * denominations one at a time, in an outer loop, and for each
 * denomination c we update dp[x] for every x >= c in increasing order:
 *   dp[x] += dp[x - c]
 * This says: every way to make (x - c) using coins up to and including
 * denomination c, with one more coin c appended, is a way to make x.
 * Because we loop over coins in the OUTER loop and amounts in the INNER
 * loop (ascending), each combination of coins is only ever counted once,
 * regardless of the order the coins would be picked up in -- this is the
 * key trick that distinguishes "counting combinations" from "counting
 * sequences/permutations".
 * Base case: dp[0] = 1 (there is exactly one way to make amount 0: use
 * no coins at all).
 *
 * Time complexity: O(amount * numCoins).
 * Space complexity: O(amount) for the dp array.
 */
public class CoinChangeWays {

    public static long countWays(int[] coins, int amount) {
        long[] dp = new long[amount + 1];
        dp[0] = 1;

        for (int coin : coins) {
            for (int x = coin; x <= amount; x++) {
                dp[x] += dp[x - coin];
            }
        }
        return dp[amount];
    }

    public static void main(String[] args) {
        int[] coins = {1, 2, 5};
        int amount = 5;

        System.out.println("Coin Change - Number of Ways");
        System.out.print("Denominations: ");
        for (int c : coins) {
            System.out.print(c + " ");
        }
        System.out.println();
        System.out.println("Target amount: " + amount);

        long result = countWays(coins, amount);
        System.out.println();
        System.out.println("Final computed answer -> Number of ways to make the amount: " + result);
    }
}
