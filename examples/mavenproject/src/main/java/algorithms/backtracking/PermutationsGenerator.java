import java.util.ArrayList;
import java.util.List;

/**
 * PERMUTATIONS GENERATOR (BACKTRACKING)
 * -----------------------------------------
 * Generates every possible ordering (permutation) of a set of distinct
 * elements. For n elements there are exactly n! permutations.
 *
 * Core idea (backtrack-and-undo): we build a permutation one position at a
 * time. At each step, we try every element that hasn't been used yet: we
 * "choose" it (add it to the current partial permutation and mark it used),
 * "explore" by recursing to fill the next position, and once that recursive
 * branch has been fully explored we "undo" the choice (remove it from the
 * partial permutation and mark it unused again) before trying the next
 * candidate element. This undo step lets the same array slot be reused by a
 * sibling branch of the recursion tree instead of allocating a fresh list
 * every time, which is the hallmark of backtracking. When the partial
 * permutation reaches the full length n, it is a complete permutation and we
 * record a copy of it.
 *
 * Complexity (n = number of elements):
 *   - Time: O(n! * n) -- there are n! permutations, and building/copying each
 *     one costs O(n).
 *   - Space: O(n) auxiliary (the "used" array and recursion depth), plus
 *     O(n! * n) to store all the output permutations.
 */
public class PermutationsGenerator {

    private final int[] elements;
    private final boolean[] used;
    private final int[] current;
    private final List<List<Integer>> results = new ArrayList<>();

    public PermutationsGenerator(int[] elements) {
        this.elements = elements;
        this.used = new boolean[elements.length];
        this.current = new int[elements.length];
    }

    public List<List<Integer>> generate() {
        results.clear();
        backtrack(0);
        return results;
    }

    private void backtrack(int depth) {
        if (depth == elements.length) {
            List<Integer> perm = new ArrayList<>();
            for (int v : current) perm.add(v);
            results.add(perm);
            return;
        }
        for (int i = 0; i < elements.length; i++) {
            if (used[i]) continue;
            used[i] = true;             // choose
            current[depth] = elements[i];
            backtrack(depth + 1);       // explore
            used[i] = false;            // undo (backtrack)
        }
    }

    public static void main(String[] args) {
        int[] elements = {1, 2, 3};
        PermutationsGenerator generator = new PermutationsGenerator(elements);
        List<List<Integer>> perms = generator.generate();

        System.out.println("Permutations of " + java.util.Arrays.toString(elements) + ":");
        for (List<Integer> p : perms) {
            System.out.println(p);
        }
        System.out.println("Total count: " + perms.size() + " (expected 3! = 6)");
    }
}
