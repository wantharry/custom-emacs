/**
 * QUEUE (ARRAY-BACKED, LINEAR, FIFO)
 * ------------------------------------
 * A queue is a First-In-First-Out structure: the earliest-enqueued element is
 * the first one dequeued. This version uses a plain fixed-size array with two
 * indices, "front" and "rear", and does NOT wrap around (see CircularQueue for
 * the wraparound version that reuses freed slots at the start of the array).
 *
 * Core idea: enqueue places a value at array[rear] and increments rear; dequeue
 * reads array[front] and increments front. Because rear only ever increases and
 * never wraps back to 0, slots before "front" become permanently unusable even
 * though they are logically empty -- this is the classic limitation a linear
 * array queue has versus a circular one, and the demo below deliberately shows
 * the queue reporting "full" once rear reaches capacity, even if several items
 * near the front have already been dequeued.
 *
 * Complexity (n = number of elements currently stored, c = fixed capacity):
 *   - enqueue / dequeue / peek / isEmpty: O(1) time, O(1) extra space
 *   - overall space: O(c)
 */
public class QueueUsingArray {

    private final int[] data;
    private int front;
    private int rear;  // index of next free slot
    private int count;

    public QueueUsingArray(int capacity) {
        data = new int[capacity];
        front = 0;
        rear = 0;
        count = 0;
    }

    public boolean isFull() {
        return rear == data.length;
    }

    public boolean isEmpty() {
        return count == 0;
    }

    public void enqueue(int value) {
        if (isFull()) throw new RuntimeException("Queue is full (no wraparound in this linear version)");
        data[rear++] = value;
        count++;
    }

    public int dequeue() {
        if (isEmpty()) throw new RuntimeException("Queue is empty");
        int value = data[front++];
        count--;
        return value;
    }

    public int peek() {
        if (isEmpty()) throw new RuntimeException("Queue is empty");
        return data[front];
    }

    public int size() {
        return count;
    }

    public static void main(String[] args) {
        QueueUsingArray queue = new QueueUsingArray(5);
        queue.enqueue(1);
        queue.enqueue(2);
        queue.enqueue(3);
        System.out.println("Dequeue: " + queue.dequeue());
        System.out.println("Dequeue: " + queue.dequeue());
        System.out.println("Size now (only 1 logical element left): " + queue.size());

        queue.enqueue(4);
        queue.enqueue(5);
        System.out.println("rear has reached capacity, isFull: " + queue.isFull());

        // Even though only 3 elements are logically present (one slot was
        // freed by the dequeues above), rear cannot wrap around in this
        // linear version, so a further enqueue is rejected as "full".
        try {
            queue.enqueue(6);
        } catch (RuntimeException e) {
            System.out.println("enqueue(6) rejected as expected: " + e.getMessage());
        }

        System.out.println("Remaining items dequeued in order: ");
        while (!queue.isEmpty()) {
            System.out.println(queue.dequeue());
        }
    }
}
