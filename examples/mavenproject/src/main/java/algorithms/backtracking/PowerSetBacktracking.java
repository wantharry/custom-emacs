import java.util.ArrayList;
import java.util.List;

/**
 * POWER SET VIA BIT-DECISION BACKTRACKING
 * --------------------------------------------
 * The power set of a set of n elements is the collection of all 2^n possible
 * subsets. This file generates it with a different backtracking shape than a
 * typical subset-generator: instead of branching on a growing start index, at
 * each element we make an explicit binary decision -- include it or don't --
 * which mirrors treating the power set as "every possible n-bit on/off
 * choice vector" over the elements.
 *
 * Core idea (backtrack-and-undo): we recurse over the elements by index. At
 * index i, we first "choose" to include elements[i] in the current subset,
 * recurse to decide element i+1 ("explore"), then "undo" that inclusion by
 * removing it again, and separately recurse to decide element i+1 while
 * excluding elements[i] -- i.e. we explicitly explore BOTH the true and false
 * branches of the binary decision for this element before moving on. A
 * subset is complete and recorded only once we've made a decision for every
 * element (index reaches n). This two-branch-per-element shape is the direct
 * recursive encoding of "for each element, is it in or out", distinct from
 * the index-sweeping approach used in SubsetsGenerator.
 *
 * Complexity (n = number of elements):
 *   - Time: O(2^n * n) -- 2^n leaves of the decision tree, each requiring up
 *     to O(n) to copy out the resulting subset.
 *   - Space: O(n) recursion depth, plus O(2^n * n) to store all subsets.
 */
public class PowerSetBacktracking {

    private final int[] elements;
    private final List<Integer> current = new ArrayList<>();
    private final List<List<Integer>> results = new ArrayList<>();

    public PowerSetBacktracking(int[] elements) {
        this.elements = elements;
    }

    public List<List<Integer>> generate() {
        results.clear();
        current.clear();
        decide(0);
        return results;
    }

    private void decide(int index) {
        if (index == elements.length) {
            results.add(new ArrayList<>(current));
            return;
        }

        // Branch 1: include elements[index].
        current.add(elements[index]);  // choose
        decide(index + 1);             // explore
        current.remove(current.size() - 1); // undo (backtrack)

        // Branch 2: exclude elements[index].
        decide(index + 1);             // explore the other possibility
    }

    public static void main(String[] args) {
        int[] elements = {1, 2, 3};
        PowerSetBacktracking generator = new PowerSetBacktracking(elements);
        List<List<Integer>> powerSet = generator.generate();

        System.out.println("Power set of " + java.util.Arrays.toString(elements) + ":");
        for (List<Integer> subset : powerSet) {
            System.out.println(subset);
        }
        System.out.println("Total count: " + powerSet.size() + " (expected 2^3 = 8)");
    }
}
