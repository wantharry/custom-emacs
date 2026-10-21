/**
 * TRIE (PREFIX TREE)
 * --------------------
 * A trie stores a set of strings so that every node represents one character
 * position, and the path from the root to a node spells out a prefix shared by
 * every string that passes through it. Each node has up to 26 children (one
 * per lowercase letter here) and a flag marking whether a complete word ends
 * at that node. Common prefixes are stored only once, which is what makes
 * prefix lookups fast and memory-efficient for many similar strings.
 *
 * Core idea: insert walks the trie one character at a time from the root,
 * creating a child node whenever the needed branch doesn't exist yet, then
 * marks the final node as "end of word". search does the same walk and only
 * returns true if it reaches a node marked end-of-word. startsWith does the
 * same walk but returns true as soon as the whole prefix is matched,
 * regardless of the end-of-word flag -- that's the operation a BST or hash set
 * cannot do efficiently, since a trie's structure is built around shared
 * prefixes rather than whole-key hashing/ordering.
 *
 * Complexity (L = length of the word/prefix involved, independent of how many
 * words are stored):
 *   - insert / search / startsWith: O(L) time, O(1) extra space (aside from
 *     the new nodes insert may create)
 *   - overall space: O(total characters across all inserted words), since
 *     shared prefixes are stored once
 */
public class Trie {

    private static class Node {
        Node[] children = new Node[26];
        boolean isEndOfWord;
    }

    private final Node root = new Node();

    public void insert(String word) {
        Node cur = root;
        for (char c : word.toCharArray()) {
            int idx = c - 'a';
            if (cur.children[idx] == null) {
                cur.children[idx] = new Node();
            }
            cur = cur.children[idx];
        }
        cur.isEndOfWord = true;
    }

    public boolean search(String word) {
        Node node = walk(word);
        return node != null && node.isEndOfWord;
    }

    public boolean startsWith(String prefix) {
        return walk(prefix) != null;
    }

    private Node walk(String s) {
        Node cur = root;
        for (char c : s.toCharArray()) {
            int idx = c - 'a';
            if (idx < 0 || idx >= 26 || cur.children[idx] == null) return null;
            cur = cur.children[idx];
        }
        return cur;
    }

    public static void main(String[] args) {
        Trie trie = new Trie();
        String[] words = {"cat", "car", "card", "care", "dog"};
        for (String w : words) trie.insert(w);

        System.out.println("search(\"car\"): " + trie.search("car"));
        System.out.println("search(\"ca\"): " + trie.search("ca"));
        System.out.println("startsWith(\"ca\"): " + trie.startsWith("ca"));
        System.out.println("startsWith(\"care\"): " + trie.startsWith("care"));
        System.out.println("startsWith(\"do\"): " + trie.startsWith("do"));
        System.out.println("startsWith(\"xyz\"): " + trie.startsWith("xyz"));
        System.out.println("search(\"dog\"): " + trie.search("dog"));
        System.out.println("search(\"dogs\"): " + trie.search("dogs"));
    }
}
