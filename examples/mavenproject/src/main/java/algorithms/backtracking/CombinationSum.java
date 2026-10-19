import java.util.ArrayList;
import java.util.List;

/**
 * COMBINATION SUM (BACKTRACKING)
 * ------------------------------------
 * Given a set of candidate numbers (each of which may be reused an unlimited
 * number of times) and a target sum, find every distinct combination of
 * candidates that adds up exactly to the target.
 *
 * Core idea (backtrack-and-undo): we try candidates in sorted order, starting
 * from a given index, to avoid generating the same combination in a different
 * order (e.g. [2,2,3] but not also [2,3,2] and [3,2,2]). At each step we
 * "choose" to include the candidate at the current index -- adding it to the
 * running combination and subtracting it from the remaining target -- then
 * "explore" by recursing, allowing the SAME index to be tried again (since
 * reuse is permitted) as well as later indices. If the remaining target hits
 * exactly 0, we record the current combination as a valid answer. If it goes
 * negative, or we've exhausted the candidates, that branch fails. Either way,
 * we "undo" the choice (remove the candidate, restore the remaining target)
 * before trying the next candidate index -- that's the backtracking step
 * that lets the same array position be reused by sibling branches.
 *
 * Complexity (n = number of candidates, T = target value):
 *   - Time is exponential in the worst case, roughly O(n^(T / minCandidate)),
 *     since the recursion depth is bounded by how many times the smallest
 *     candidate can be added before exceeding T, and branching factor is n.
 *   - Space: O(T / minCandidate) recursion depth for the current combination,
 *     plus space for all valid combinations found.
 */
public class CombinationSum {

    private final int[] candidates;
    private final List<Integer> current = new ArrayList<>();
    private final List<List<Integer>> results = new ArrayList<>();

    public CombinationSum(int[] candidates) {
        this.candidates = candidates.clone();
        java.util.Arrays.sort(this.candidates);
    }

    public List<List<Integer>> findCombinations(int target) {
        results.clear();
        current.clear();
        backtrack(0, target);
        return results;
    }

    private void backtrack(int startIndex, int remaining) {
        if (remaining == 0) {
            results.add(new ArrayList<>(current));
            return;
        }
        for (int i = startIndex; i < candidates.length; i++) {
            if (candidates[i] > remaining) break; // sorted, so no later candidate can fit either
            current.add(candidates[i]);            // choose
            backtrack(i, remaining - candidates[i]); // explore; i (not i+1) allows reuse
            current.remove(current.size() - 1);    // undo (backtrack)
        }
    }

    public static void main(String[] args) {
        int[] candidates = {2, 3, 6, 7};
        int target = 7;
        CombinationSum solver = new CombinationSum(candidates);
        List<List<Integer>> combos = solver.findCombinations(target);

        System.out.println("Candidates: " + java.util.Arrays.toString(candidates) + ", target = " + target);
        System.out.println("Combinations that sum to " + target + ":");
        for (List<Integer> combo : combos) {
            System.out.println(combo);
        }
    }
}
