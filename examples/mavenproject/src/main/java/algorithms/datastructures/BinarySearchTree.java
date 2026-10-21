/**
 * BINARY SEARCH TREE (BST)
 * --------------------------
 * A binary search tree is a node-based tree where each node has at most two
 * children, and the BST invariant holds at every node: everything in its left
 * subtree is smaller, and everything in its right subtree is larger. That
 * invariant is what makes search, insert and delete fast -- at each step we can
 * discard an entire half of the remaining tree, the same way binary search
 * discards half of a sorted array.
 *
 * Core idea: insert walks down from the root, going left or right by comparing
 * the new value against each node, until it finds an empty spot to attach a new
 * node. search does the same comparison walk. delete has three cases: a leaf is
 * just unlinked; a node with one child is replaced by that child; a node with
 * two children is replaced by its in-order successor (the smallest value in its
 * right subtree), and then that successor is deleted from its original spot.
 * In-order traversal (left, node, right) visits every value in sorted order,
 * which is a direct consequence of the BST invariant.
 *
 * Complexity (n = number of nodes, h = height of the tree):
 *   - search / insert / delete: O(h) time, which is O(log n) for a balanced
 *     tree but degrades to O(n) for a skewed tree (e.g. inserting sorted data)
 *   - inorderTraversal: O(n) time, O(h) space for the recursion stack
 *   - overall space: O(n)
 */
public class BinarySearchTree {

    private static class Node {
        int value;
        Node left, right;
        Node(int value) { this.value = value; }
    }

    private Node root;

    public void insert(int value) {
        root = insertRec(root, value);
    }

    private Node insertRec(Node node, int value) {
        if (node == null) return new Node(value);
        if (value < node.value) node.left = insertRec(node.left, value);
        else if (value > node.value) node.right = insertRec(node.right, value);
        // equal values are ignored (no duplicates)
        return node;
    }

    public boolean search(int value) {
        Node cur = root;
        while (cur != null) {
            if (value == cur.value) return true;
            cur = value < cur.value ? cur.left : cur.right;
        }
        return false;
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
            // Found the node to delete.
            if (node.left == null) return node.right;
            if (node.right == null) return node.left;
            // Two children: replace value with the in-order successor
            // (smallest value in the right subtree), then delete that successor.
            Node successor = node.right;
            while (successor.left != null) successor = successor.left;
            node.value = successor.value;
            node.right = deleteRec(node.right, successor.value);
        }
        return node;
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

    public static void main(String[] args) {
        BinarySearchTree bst = new BinarySearchTree();
        int[] values = {50, 30, 70, 20, 40, 60, 80};
        for (int v : values) bst.insert(v);

        System.out.println("In-order (sorted): " + bst.inorderTraversal());
        System.out.println("Search 40: " + bst.search(40));
        System.out.println("Search 99: " + bst.search(99));

        bst.delete(30); // two-children case
        System.out.println("After deleting 30: " + bst.inorderTraversal());

        bst.delete(70); // two-children case, root's other subtree
        System.out.println("After deleting 70: " + bst.inorderTraversal());
    }
}
