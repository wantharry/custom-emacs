/**
 * SINGLY LINKED LIST
 * -------------------
 * A singly linked list is a linear data structure made of nodes where each node
 * stores a value and a reference ("next") to the following node. Unlike an array,
 * the nodes are not stored in contiguous memory, so insertion/removal at the head
 * (or anywhere, given a reference to the previous node) does not require shifting
 * other elements.
 *
 * Core idea: we keep a reference to the "head" (first node). To insert at the
 * front we create a new node whose "next" points at the current head, then move
 * head to the new node -- O(1). To insert at the back we walk to the last node
 * (the one whose next is null) and attach the new node there -- O(n) unless a
 * tail pointer is kept. Deleting a value requires walking the list while keeping
 * a "previous" pointer so we can re-link previous.next around the removed node.
 * Searching and reversing both require a full O(n) traversal; reversing is done
 * iteratively by repeatedly redirecting each node's "next" to the node before it.
 *
 * Complexity (n = number of nodes):
 *   - insertFront: O(1) time, O(1) extra space
 *   - insertBack:  O(n) time (no tail pointer), O(1) extra space
 *   - delete(value): O(n) time, O(1) extra space
 *   - search(value): O(n) time, O(1) extra space
 *   - reverse(): O(n) time, O(1) extra space (in place)
 *   - overall space for the list itself: O(n)
 */
public class SinglyLinkedListOps {

    private static class Node {
        int value;
        Node next;
        Node(int value) { this.value = value; }
    }

    private Node head;

    public void insertFront(int value) {
        Node node = new Node(value);
        node.next = head;
        head = node;
    }

    public void insertBack(int value) {
        Node node = new Node(value);
        if (head == null) {
            head = node;
            return;
        }
        Node cur = head;
        while (cur.next != null) {
            cur = cur.next;
        }
        cur.next = node;
    }

    public boolean delete(int value) {
        if (head == null) return false;
        if (head.value == value) {
            head = head.next;
            return true;
        }
        Node prev = head;
        Node cur = head.next;
        while (cur != null) {
            if (cur.value == value) {
                prev.next = cur.next;
                return true;
            }
            prev = cur;
            cur = cur.next;
        }
        return false;
    }

    public boolean search(int value) {
        Node cur = head;
        while (cur != null) {
            if (cur.value == value) return true;
            cur = cur.next;
        }
        return false;
    }

    public void reverse() {
        Node prev = null;
        Node cur = head;
        while (cur != null) {
            Node next = cur.next;
            cur.next = prev;
            prev = cur;
            cur = next;
        }
        head = prev;
    }

    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder("[");
        Node cur = head;
        while (cur != null) {
            sb.append(cur.value);
            if (cur.next != null) sb.append(", ");
            cur = cur.next;
        }
        sb.append("]");
        return sb.toString();
    }

    public static void main(String[] args) {
        SinglyLinkedListOps list = new SinglyLinkedListOps();
        list.insertBack(10);
        list.insertBack(20);
        list.insertBack(30);
        list.insertFront(5);
        System.out.println("After inserts: " + list);

        System.out.println("Search 20: " + list.search(20));
        System.out.println("Search 99: " + list.search(99));

        list.delete(20);
        System.out.println("After deleting 20: " + list);

        list.reverse();
        System.out.println("After reverse: " + list);
    }
}
