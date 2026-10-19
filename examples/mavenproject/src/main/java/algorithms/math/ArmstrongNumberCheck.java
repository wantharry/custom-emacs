/**
 * ARMSTRONG NUMBER CHECK
 *
 * What it does:
 *   Determines whether a number is an "Armstrong number" (also called a
 *   narcissistic number): a number that equals the sum of each of its
 *   own digits raised to the power of the total digit count. Examples:
 *   153 = 1^3 + 5^3 + 3^3, and 9474 = 9^4 + 4^4 + 7^4 + 4^4.
 *
 * Core idea / how it works:
 *   First count how many digits the number has (call it k). Then peel
 *   off digits one at a time from the right using repeated % 10 and / 10,
 *   raise each digit to the power k, and accumulate the sum. Finally
 *   compare the accumulated sum to the original number -- if they match,
 *   it's an Armstrong number.
 *
 * Time complexity:  O(d)  where d is the number of digits (each digit
 *                    visited once; the power is computed with a tiny
 *                    O(d) loop too, so overall still O(d) per digit).
 * Space complexity: O(1).
 */
public class ArmstrongNumberCheck {

    public static boolean isArmstrong(long number) {
        if (number < 0) return false;
        long original = number;
        int digitCount = Long.toString(number).length();

        long sum = 0;
        long n = number;
        while (n > 0) {
            long digit = n % 10;
            sum += (long) Math.pow(digit, digitCount);
            n /= 10;
        }
        // Handle the edge case number == 0 (0 digits consumed above).
        if (original == 0) sum = 0; // 0^1 = 0, which does equal 0, but loop never ran
        return sum == original || original == 0;
    }

    public static void main(String[] args) {
        long[] candidates = {153, 9474, 9475, 0, 5, 1634, 371, 123};
        System.out.println("Armstrong number check:");
        for (long n : candidates) {
            System.out.println("  " + n + " is Armstrong? " + isArmstrong(n));
        }
    }
}
