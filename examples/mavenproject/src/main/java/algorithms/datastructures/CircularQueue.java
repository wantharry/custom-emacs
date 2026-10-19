/**
 * CIRCULAR QUEUE (ARRAY-BACKED, FIFO, WRAPAROUND)
 * -------------------------------------------------
 * A circular queue fixes the wasted-space problem of a plain linear array
 * queue: once "rear" runs off the end of the backing array it wraps back to
 * index 0, as long as there is still logically free room (tracked by a count
 * of current elements, since front==rear alone is ambiguous between "empty"
 * and "full").
 *
 * Core idea: both front and rear move with modulo arithmetic, e.g.
 * rear = (rear + 1) % capacity. This treats the array as a ring buffer, so
 * slots freed near the front are reused by later enqueues instead of being
 * stranded. We track an explicit element count to distinguish empty vs full
 * states, both of which would otherwise show front == rear.
 *
 * Complexity (n = number of elements currently stored, c = fixed capacity):
 *   - enqueue / dequeue / peek / isEmpty / isFull: O(1) time, O(1) extra space
 *   - overall space: O(c)
 */
public class CircularQueue {

    private final int[] data;
    private int front;
    private int rear;
    private int count;

    public CircularQueue(int capacity) {
        data = new int[capacity];
        front = 0;
        rear = -1;
        count = 0;
    }

    public boolean isEmpty() {
        return count == 0;
    }

    public boolean isFull() {
        return count == data.length;
    }

    public void enqueue(int value) {
        if (isFull()) throw new RuntimeException("Circular queue is full");
        rear = (rear + 1) % data.length;
        data[rear] = value;
        count++;
    }

    public int dequeue() {
        if (isEmpty()) throw new RuntimeException("Circular queue is empty");
        int value = data[front];
        front = (front + 1) % data.length;
        count--;
        return value;
    }

    public int peek() {
        if (isEmpty()) throw new RuntimeException("Circular queue is empty");
        return data[front];
    }

    public int size() {
        return count;
    }

    public static void main(String[] args) {
        CircularQueue queue = new CircularQueue(4);
        queue.enqueue(1);
        queue.enqueue(2);
        queue.enqueue(3);
        queue.enqueue(4);
        System.out.println("Full after 4 enqueues into capacity-4 queue: " + queue.isFull());

        System.out.println("Dequeue: " + queue.dequeue());
        System.out.println("Dequeue: " + queue.dequeue());
        // These reuse the two slots just freed at the "front" of the ring buffer.
        queue.enqueue(5);
        queue.enqueue(6);
        System.out.println("Full again after wraparound enqueues: " + queue.isFull());

        System.out.print("Draining in FIFO order: ");
        while (!queue.isEmpty()) {
            System.out.print(queue.dequeue() + " ");
        }
        System.out.println();
    }
}
