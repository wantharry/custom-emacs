import java.util.HashMap;
import java.util.Map;

/**
 * LRU CACHE (LEAST RECENTLY USED, O(1) GET/PUT)
 * --------------------------------------------------
 * An LRU cache holds a fixed-capacity set of key-value pairs; when it is full
 * and a new key must be inserted, it evicts whichever entry was least
 * recently accessed (by either get or put). The classic O(1) implementation
 * combines two structures: a hash map for O(1) key lookup, and a doubly
 * linked list that keeps entries ordered by recency of use, from
 * most-recently-used at the head to least-recently-used at the tail.
 *
 * Core idea: the hash map maps each key directly to its node in the linked
 * list, so we never have to search the list. On get(key): look up the node
 * via the map, unlink it from its current position, and re-insert it at the
 * head (most-recently-used) -- O(1) because we already have a direct
 * reference to the node (no traversal needed). On put(key, value): if the key
 * exists, update its value and move it to the head the same way; if not,
 * create a new node at the head, and if that pushes the size over capacity,
 * remove the tail node (least-recently-used) and also remove its key from the
 * map. Sentinel head/tail nodes avoid special-casing empty-list edge cases.
 *
 * Complexity (c = capacity):
 *   - get / put: O(1) time (hash map lookup + O(1) linked-list splice)
 *   - overall space: O(c)
 */
public class LRUCache {

    private static class Node {
        int key, value;
        Node prev, next;
        Node(int key, int value) { this.key = key; this.value = value; }
    }

    private final int capacity;
    private final Map<Integer, Node> map = new HashMap<>();
    private final Node head = new Node(-1, -1); // sentinel, head.next = most recently used
    private final Node tail = new Node(-1, -1); // sentinel, tail.prev = least recently used

    public LRUCache(int capacity) {
        this.capacity = capacity;
        head.next = tail;
        tail.prev = head;
    }

    public int get(int key) {
        Node node = map.get(key);
        if (node == null) return -1;
        moveToHead(node);
        return node.value;
    }

    public void put(int key, int value) {
        Node existing = map.get(key);
        if (existing != null) {
            existing.value = value;
            moveToHead(existing);
            return;
        }
        Node node = new Node(key, value);
        map.put(key, node);
        insertAtHead(node);

        if (map.size() > capacity) {
            Node lru = tail.prev;
            unlink(lru);
            map.remove(lru.key);
        }
    }

    private void unlink(Node node) {
        node.prev.next = node.next;
        node.next.prev = node.prev;
    }

    private void insertAtHead(Node node) {
        node.next = head.next;
        node.prev = head;
        head.next.prev = node;
        head.next = node;
    }

    private void moveToHead(Node node) {
        unlink(node);
        insertAtHead(node);
    }

    public static void main(String[] args) {
        LRUCache cache = new LRUCache(3);
        cache.put(1, 100);
        cache.put(2, 200);
        cache.put(3, 300);
        System.out.println("get(1): " + cache.get(1)); // 100, also makes 1 most-recently-used

        cache.put(4, 400); // capacity exceeded; evicts 2 (least recently used, since 1 was just touched)
        System.out.println("get(2) after eviction: " + cache.get(2)); // -1, evicted
        System.out.println("get(3): " + cache.get(3)); // 300
        System.out.println("get(4): " + cache.get(4)); // 400

        cache.put(3, 333); // update existing key's value, also refreshes recency
        System.out.println("get(3) after update: " + cache.get(3)); // 333

        cache.put(5, 500); // evicts 1 now (it's the least recently used at this point)
        System.out.println("get(1) after second eviction: " + cache.get(1)); // -1
        System.out.println("get(5): " + cache.get(5)); // 500
    }
}
