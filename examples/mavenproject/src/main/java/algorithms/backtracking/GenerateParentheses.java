import java.util.ArrayList;
import java.util.List;

/**
 * GENERATE PARENTHESES (BACKTRACKING)
 * ----------------------------------------
 * Given n pairs of parentheses, generate every string of length 2n that
 * consists of well-formed (balanced) combinations of '(' and ')'.
 *
 * Core idea (backtrack-and-undo): we build the string character by character,
 * tracking how many '(' and ')' we've used so far. At each position we have
 * up to two choices: add '(' if we haven't used all n opens yet, or add ')'
 * if doing so wouldn't exceed the number of opens used so far (this is the
 * key legality rule -- a close can never outnumber the opens that precede
 * it, otherwise the string isn't balanced). We "choose" one option by
 * appending the character and recursing ("explore"); once that recursive
 * branch is fully explored we "undo" by removing the last character
 * (backtrack) before trying the other option. A complete, valid string is
 * recorded once its length reaches 2n (at which point opens must equal
 * closes must equal n).
 *
 * Complexity (n = number of pairs):
 *   - Time: O(4^n / sqrt(n)) -- this is the n-th Catalan number (the number
 *     of valid sequences) times O(n) to build each string; the Catalan
 *     number itself is the tight bound on the branching after pruning
 *     invalid moves.
 *   - Space: O(n) for the recursion depth / current string buffer, plus
 *     space to store all generated strings.
 */
public class GenerateParentheses {

    private final int n;
    private final StringBuilder current = new StringBuilder();
    private final List<String> results = new ArrayList<>();

    public GenerateParentheses(int n) {
        this.n = n;
    }

    public List<String> generate() {
        results.clear();
        current.setLength(0);
        backtrack(0, 0);
        return results;
    }

    private void backtrack(int opens, int closes) {
        if (current.length() == 2 * n) {
            results.add(current.toString());
            return;
        }
        if (opens < n) {
            current.append('(');       // choose
            backtrack(opens + 1, closes); // explore
            current.deleteCharAt(current.length() - 1); // undo
        }
        if (closes < opens) {
            current.append(')');       // choose
            backtrack(opens, closes + 1); // explore
            current.deleteCharAt(current.length() - 1); // undo
        }
    }

    public static void main(String[] args) {
        int n = 3;
        GenerateParentheses generator = new GenerateParentheses(n);
        List<String> combos = generator.generate();

        System.out.println("Valid parentheses combinations for n = " + n + ":");
        for (String s : combos) {
            System.out.println(s);
        }
        System.out.println("Total count: " + combos.size() + " (expected Catalan(3) = 5)");
    }
}
