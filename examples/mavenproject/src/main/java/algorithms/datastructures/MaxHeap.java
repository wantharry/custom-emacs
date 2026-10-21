/**
 * MAX-HEAP (BINARY HEAP, ARRAY-BACKED)
 * ---------------------------------------
 * A max-heap is the mirror image of a min-heap: a complete binary tree stored
 * implicitly in an array where every parent is greater than or equal to both of
 * its children, so the overall maximum always sits at the root (index 0). For a
 * node at index i, its children live at 2i+1 and 2i+2, and its parent lives at
 * (i-1)/2 -- the array encodes the tree shape without needing any pointers.
 *
 * Core idea: insert() appends the new value at the end, then "sifts up" --
 * swapping it with its parent while it is larger than that parent -- until the
 * heap property holds again. extractMax() swaps the root with the last element,
 * shrinks the logical size, then "sifts down" that element -- swapping it with
 * its larger child -- until it settles where it's no smaller than either child.
 *
 * Complexity (n = number of elements):
 *   - insert: O(log n) time (height of the tree), O(1) extra space
 *   - extractMax: O(log n) time, O(1) extra space
 *   - peekMax: O(1) time
 *   - overall space: O(n)
 */
public class MaxHeap {

    private int[] data;
    private int size;

    public MaxHeap(int capacity) {
        data = new int[Math.max(1, capacity)];
        size = 0;
    }

    public void insert(int value) {
        if (size == data.length) grow();
        data[size] = value;
        siftUp(size);
        size++;
    }

    public int extractMax() {
        if (size == 0) throw new RuntimeException("Heap is empty");
        int max = data[0];
        size--;
        data[0] = data[size];
        siftDown(0);
        return max;
    }

    public int peekMax() {
        if (size == 0) throw new RuntimeException("Heap is empty");
        return data[0];
    }

    public int size() {
        return size;
    }

    private void siftUp(int i) {
        while (i > 0) {
            int parent = (i - 1) / 2;
            if (data[i] <= data[parent]) break;
            swap(i, parent);
            i = parent;
        }
    }

    private void siftDown(int i) {
        while (true) {
            int left = 2 * i + 1;
            int right = 2 * i + 2;
            int largest = i;
            if (left < size && data[left] > data[largest]) largest = left;
            if (right < size && data[right] > data[largest]) largest = right;
            if (largest == i) break;
            swap(i, largest);
            i = largest;
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
        MaxHeap heap = new MaxHeap(4);
        int[] values = {7, 2, 9, 1, 5, 3};
        for (int v : values) heap.insert(v);

        System.out.println("Current max: " + heap.peekMax());
        System.out.print("Extracting in descending order: ");
        while (heap.size() > 0) {
            System.out.print(heap.extractMax() + " ");
        }
        System.out.println();
    }
}
