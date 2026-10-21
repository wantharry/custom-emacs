/**
 * AVL TREE (SELF-BALANCING BINARY SEARCH TREE)
 * -----------------------------------------------
 * A plain BST can degrade into a linked list (O(n) operations) if values are
 * inserted in sorted order. An AVL tree prevents that by enforcing, at every
 * node, that the heights of its left and right subtrees differ by at most 1
 * (the "balance factor" is in {-1, 0, 1}). Keeping that invariant guarantees
 * the tree height stays O(log n), so every operation stays fast.
 *
 * Core idea: insert and delete work like a normal BST, but after the recursive
 * call returns up through each ancestor we (1) recompute that node's height
 * from its children's heights and (2) check its balance factor
 * (height(left) - height(right)). If it falls outside [-1, 1] the subtree is
 * rebalanced with rotations:
 *   - Left-Left case (left-heavy, left child itself left-heavy): single right rotation.
 *   - Right-Right case (mirror): single left rotation.
 *   - Left-Right case (left-heavy, left child right-heavy): rotate left child
 *     left, then rotate the node right (a "double rotation").
 *   - Right-Left case (mirror): rotate right child right, then rotate the node left.
 * A rotation re-parents a small number of nodes in O(1) and restores balance
 * for that subtree, which is also enough to restore it for the whole tree
 * since heights only change by at most 1 after a single insert/delete.
 *
 * Complexity (n = number of nodes; height is guaranteed O(log n)):
 *   - search / insert / delete: O(log n) time, O(log n) space (recursion stack)
 *   - overall space: O(n)
 */
public class AVLTree {

    private static class Node {
        int value;
        int height;
        Node left, right;
        Node(int value) {
            this.value = value;
            this.height = 1;
        }
    }

    private Node root;

    public void insert(int value) {
        root = insertRec(root, value);
    }

    private Node insertRec(Node node, int value) {
        if (node == null) return new Node(value);
        if (value < node.value) node.left = insertRec(node.left, value);
        else if (value > node.value) node.right = insertRec(node.right, value);
        else return node; // no duplicates

        updateHeight(node);
        return rebalance(node);
    }

    public void delete(int value) {
        root = deleteRec(root, value);
    }

    private Node deleteRec(Node node, int value) {
        if (node == null) return null;
        if (value < node.value) {
            node.left = deleteRec(node.left, value);
        } else if (value > node.value) {
            node.right = deleteRec(node.right, value);
        } else {
            if (node.left == null) return node.right;
            if (node.right == null) return node.left;
            Node successor = node.right;
            while (successor.left != null) successor = successor.left;
            node.value = successor.value;
            node.right = deleteRec(node.right, successor.value);
        }
        updateHeight(node);
        return rebalance(node);
    }

    public boolean search(int value) {
        Node cur = root;
        while (cur != null) {
            if (value == cur.value) return true;
            cur = value < cur.value ? cur.left : cur.right;
        }
        return false;
    }

    private int height(Node node) {
        return node == null ? 0 : node.height;
    }

    private void updateHeight(Node node) {
        node.height = 1 + Math.max(height(node.left), height(node.right));
    }

    private int balanceFactor(Node node) {
        return height(node.left) - height(node.right);
    }

    private Node rebalance(Node node) {
        int bf = balanceFactor(node);

        if (bf > 1) { // left-heavy
            if (balanceFactor(node.left) < 0) {
                node.left = rotateLeft(node.left); // Left-Right case
            }
            return rotateRight(node); // Left-Left case
        }
        if (bf < -1) { // right-heavy
            if (balanceFactor(node.right) > 0) {
                node.right = rotateRight(node.right); // Right-Left case
            }
            return rotateLeft(node); // Right-Right case
        }
        return node;
    }

    private Node rotateRight(Node y) {
        Node x = y.left;
        Node t2 = x.right;
        x.right = y;
        y.left = t2;
        updateHeight(y);
        updateHeight(x);
        return x;
    }

    private Node rotateLeft(Node x) {
        Node y = x.right;
        Node t2 = y.left;
        y.left = x;
        x.right = t2;
        updateHeight(x);
        updateHeight(y);
        return y;
    }

    public java.util.List<Integer> inorderTraversal() {
        java.util.List<Integer> result = new java.util.ArrayList<>();
        inorderRec(root, result);
        return result;
    }

    private void inorderRec(Node node, java.util.List<Integer> result) {
        if (node == null) return;
        inorderRec(node.left, result);
        result.add(node.value);
        inorderRec(node.right, result);
    }

    public int height() {
        return height(root);
    }

    public static void main(String[] args) {
        AVLTree tree = new AVLTree();
        // Inserting in strictly increasing order would make a plain BST
        // degenerate into a linked list of height 7; AVL keeps it balanced.
        int[] values = {10, 20, 30, 40, 50, 60, 70};
        for (int v : values) tree.insert(v);

        System.out.println("In-order (sorted): " + tree.inorderTraversal());
        System.out.println("Height after 7 sequential inserts (balanced, not 7): " + tree.height());

        tree.insert(25);
        tree.insert(5);
        System.out.println("After more inserts: " + tree.inorderTraversal());
        System.out.println("Search 40: " + tree.search(40));

        tree.delete(40);
        tree.delete(60);
        System.out.println("After deletions: " + tree.inorderTraversal());
        System.out.println("Final height (still logarithmic): " + tree.height());
    }
}
