/**
 * STACK (ARRAY-BACKED, LIFO)
 * ---------------------------
 * A stack is a Last-In-First-Out structure: the most recently pushed element is
 * the first one popped. Here it is backed by a plain Java array and a "top"
 * index that points at the next free slot.
 *
 * Core idea: push places the new element at array[top] and increments top; pop
 * decrements top and returns array[top]. When the array fills up we grow it by
 * allocating a new array of double the capacity and copying elements over
 * (amortized O(1) push even with resizing).
 *
 * Complexity (n = number of elements currently stored):
 *   - push: O(1) amortized (O(n) on the rare resize), O(1) extra space amortized
 *   - pop / peek / isEmpty: O(1) time, O(1) extra space
 *   - overall space: O(n)
 */
public class StackUsingArray {

    private int[] data;
    private int top; // number of elements, also index of next free slot

    public StackUsingArray(int initialCapacity) {
        data = new int[Math.max(1, initialCapacity)];
        top = 0;
    }

    public void push(int value) {
        if (top == data.length) {
            int[] bigger = new int[data.length * 2];
            System.arraycopy(data, 0, bigger, 0, data.length);
            data = bigger;
        }
        data[top++] = value;
    }

    public int pop() {
        if (isEmpty()) throw new RuntimeException("Stack is empty");
        return data[--top];
    }

    public int peek() {
        if (isEmpty()) throw new RuntimeException("Stack is empty");
        return data[top - 1];
    }

    public boolean isEmpty() {
        return top == 0;
    }

    public int size() {
        return top;
    }

    public static void main(String[] args) {
        StackUsingArray stack = new StackUsingArray(2);
        stack.push(10);
        stack.push(20);
        stack.push(30); // forces a resize since initial capacity was 2
        System.out.println("Size after 3 pushes: " + stack.size());
        System.out.println("Peek: " + stack.peek());

        System.out.println("Pop: " + stack.pop());
        System.out.println("Pop: " + stack.pop());
        System.out.println("Is empty now? " + stack.isEmpty());
        System.out.println("Pop: " + stack.pop());
        System.out.println("Is empty now? " + stack.isEmpty());
    }
}
