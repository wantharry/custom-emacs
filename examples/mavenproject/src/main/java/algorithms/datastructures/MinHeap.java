/**
 * MIN-HEAP (BINARY HEAP, ARRAY-BACKED)
 * ---------------------------------------
 * A min-heap is a complete binary tree, stored implicitly in an array, where
 * every parent is less than or equal to both of its children. That invariant
 * guarantees the overall minimum is always at the root (index 0). "Complete"
 * means every level is fully filled except possibly the last, which fills
 * left-to-right -- that's exactly what lets us store it in a flat array with
 * no pointers: for a node at index i, its children live at 2i+1 and 2i+2, and
 * its parent lives at (i-1)/2.
 *
 * Core idea: insert() appends the new value at the end of the array, then
 * "sifts up" -- repeatedly swapping it with its parent while it is smaller than
 * that parent -- until the heap property is restored. extractMin() swaps the
 * root with the last element, shrinks the array, then "sifts down" that element
 * -- repeatedly swapping it with its smaller child -- until it settles in a
 * spot where it's no bigger than either child.
 *
 * Complexity (n = number of elements):
 *   - insert: O(log n) time (height of the tree), O(1) extra space
 *   - extractMin: O(log n) time, O(1) extra space
 *   - peekMin: O(1) time
 *   - overall space: O(n)
 */
public class MinHeap {

    private int[] data;
    private int size;

    public MinHeap(int capacity) {
        data = new int[Math.max(1, capacity)];
        size = 0;
    }

    public void insert(int value) {
        if (size == data.length) grow();
        data[size] = value;
        siftUp(size);
        size++;
    }

    public int extractMin() {
        if (size == 0) throw new RuntimeException("Heap is empty");
        int min = data[0];
        size--;
        data[0] = data[size];
        siftDown(0);
        return min;
    }

    public int peekMin() {
        if (size == 0) throw new RuntimeException("Heap is empty");
        return data[0];
    }

    public int size() {
        return size;
    }

    private void siftUp(int i) {
        while (i > 0) {
            int parent = (i - 1) / 2;
            if (data[i] >= data[parent]) break;
            swap(i, parent);
            i = parent;
        }
    }

    private void siftDown(int i) {
        while (true) {
            int left = 2 * i + 1;
            int right = 2 * i + 2;
            int smallest = i;
            if (left < size && data[left] < data[smallest]) smallest = left;
            if (right < size && data[right] < data[smallest]) smallest = right;
            if (smallest == i) break;
            swap(i, smallest);
            i = smallest;
        }
    }

    private void swap(int i, int j) {
        int t = data[i];
        data[i] = data[j];
        data[j] = t;
    }

    private void grow() {
        int[] bigger = new int[data.length * 2];
        System.arraycopy(data, 0, bigger, 0, data.length);
        data = bigger;
    }

    public static void main(String[] args) {
        MinHeap heap = new MinHeap(4);
        int[] values = {7, 2, 9, 1, 5, 3};
        for (int v : values) heap.insert(v);

        System.out.println("Current min: " + heap.peekMin());
        System.out.print("Extracting in ascending order: ");
        while (heap.size() > 0) {
            System.out.print(heap.extractMin() + " ");
        }
        System.out.println();
    }
}
