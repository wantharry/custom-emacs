/**
 * DOUBLY LINKED LIST
 * -------------------
 * Like a singly linked list, but every node additionally stores a reference to
 * the previous node ("prev"), not just the next one. This lets us traverse in
 * both directions and delete a known node in O(1) once we have a reference to
 * it, since we no longer need to walk from the head to find its predecessor.
 *
 * Core idea: head and tail pointers are both maintained. Inserting at the front
 * or back is O(1): we just wire up prev/next pointers of the new node and the
 * old boundary node. Deleting a node is O(1) given the node itself (patch
 * node.prev.next = node.next and node.next.prev = node.prev, handling the head/
 * tail edge cases). Forward traversal walks via "next"; backward traversal walks
 * via "prev" starting from tail.
 *
 * Complexity (n = number of nodes):
 *   - insertFront / insertBack: O(1) time, O(1) extra space
 *   - delete(value): O(n) time to find the node + O(1) to unlink, O(1) extra space
 *   - traverseForward / traverseBackward: O(n) time, O(1) extra space
 *   - overall space for the list itself: O(n)
 */
public class DoublyLinkedListOps {

    private static class Node {
        int value;
        Node prev;
        Node next;
        Node(int value) { this.value = value; }
    }

    private Node head;
    private Node tail;

    public void insertFront(int value) {
        Node node = new Node(value);
        if (head == null) {
            head = tail = node;
            return;
        }
        node.next = head;
        head.prev = node;
        head = node;
    }

    public void insertBack(int value) {
        Node node = new Node(value);
        if (tail == null) {
            head = tail = node;
            return;
        }
        node.prev = tail;
        tail.next = node;
        tail = node;
    }

    public boolean delete(int value) {
        Node cur = head;
        while (cur != null) {
            if (cur.value == value) {
                if (cur.prev != null) cur.prev.next = cur.next; else head = cur.next;
                if (cur.next != null) cur.next.prev = cur.prev; else tail = cur.prev;
                return true;
            }
            cur = cur.next;
        }
        return false;
    }

    public String traverseForward() {
        StringBuilder sb = new StringBuilder("[");
        Node cur = head;
        while (cur != null) {
            sb.append(cur.value);
            if (cur.next != null) sb.append(", ");
            cur = cur.next;
        }
        return sb.append("]").toString();
    }

    public String traverseBackward() {
        StringBuilder sb = new StringBuilder("[");
        Node cur = tail;
        while (cur != null) {
            sb.append(cur.value);
            if (cur.prev != null) sb.append(", ");
            cur = cur.prev;
        }
        return sb.append("]").toString();
    }

    public static void main(String[] args) {
        DoublyLinkedListOps list = new DoublyLinkedListOps();
        list.insertBack(1);
        list.insertBack(2);
        list.insertBack(3);
        list.insertFront(0);
        System.out.println("Forward:  " + list.traverseForward());
        System.out.println("Backward: " + list.traverseBackward());

        list.delete(2);
        System.out.println("After deleting 2, forward: " + list.traverseForward());
        System.out.println("After deleting 2, backward: " + list.traverseBackward());
    }
}
