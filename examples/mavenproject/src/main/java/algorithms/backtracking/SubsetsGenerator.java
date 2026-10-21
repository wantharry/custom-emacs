import java.util.ArrayList;
import java.util.List;

/**
 * SUBSETS GENERATOR (BACKTRACKING)
 * -------------------------------------
 * Generates every subset (the power set) of a given set of distinct
 * elements, including the empty set and the full set itself. For n elements
 * there are exactly 2^n subsets, since each element is independently either
 * included or excluded.
 *
 * Core idea (backtrack-and-undo): we walk through the elements in order,
 * starting at index 0. At each index, we record the current partial subset as
 * a valid result (every partial state along the way is itself a complete
 * subset of the elements considered so far), then recurse twice: once
 * "choosing" to include the element at the current index (added to the
 * running subset) and recursing on the next index, then "undoing" that choice
 * by removing the element again and recursing on the next index without it.
 * Trying both the include-branch and the exclude-branch from every index, and
 * undoing after the include-branch finishes, is exactly what builds all 2^n
 * combinations of in/out decisions.
 *
 * Complexity (n = number of elements):
 *   - Time: O(2^n * n) -- there are 2^n subsets, and copying each one costs
 *     up to O(n).
 *   - Space: O(n) auxiliary (recursion depth + the current running subset),
 *     plus O(2^n * n) to store all the output subsets.
 */
public class SubsetsGenerator {

    private final int[] elements;
    private final List<Integer> current = new ArrayList<>();
    private final List<List<Integer>> results = new ArrayList<>();

    public SubsetsGenerator(int[] elements) {
        this.elements = elements;
    }

    public List<List<Integer>> generate() {
        results.clear();
        backtrack(0);
        return results;
    }

    private void backtrack(int index) {
        // Every partial state is itself a complete subset of elements[0..index-1].
        results.add(new ArrayList<>(current));

        if (index == elements.length) return;

        for (int i = index; i < elements.length; i++) {
            current.add(elements[i]);   // choose: include elements[i]
            backtrack(i + 1);           // explore
            current.remove(current.size() - 1); // undo (backtrack)
        }
    }

    public static void main(String[] args) {
        int[] elements = {1, 2, 3};
        SubsetsGenerator generator = new SubsetsGenerator(elements);
        List<List<Integer>> subsets = generator.generate();

        System.out.println("Subsets of " + java.util.Arrays.toString(elements) + ":");
        for (List<Integer> s : subsets) {
            System.out.println(s);
        }
        System.out.println("Total count: " + subsets.size() + " (expected 2^3 = 8)");
    }
}
