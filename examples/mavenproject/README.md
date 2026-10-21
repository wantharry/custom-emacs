# Algorithms (sample Maven project)

100 self-contained Java algorithm implementations for learning, and a sample project for
trying out this `java` branch's Maven integration (`C-c j` below) on a real multi-file
build.

## Running one algorithm

Open any `.java` file in `src/main/java/algorithms/<category>/` and press `C-c J`. Each
file has no `package` statement and its own `main`, so it compiles and runs on its own.

## Building/testing the whole project

From this directory (or any file inside it), the Maven commands added on the `java`
branch:

| Key | Does |
|---|---|
| `C-c j c` | `mvn compile` — compile everything at once |
| `C-c j t` | `mvn test` |
| `C-c j p` | `mvn package` |
| `C-c j i` | `mvn install` |
| `C-c j C` | `mvn clean` |
| `C-c j g` | prompts for any goals, e.g. `clean compile` |

## Layout (9 categories, 100 files)

| Folder | Count | Topics |
|---|---|---|
| `sorting/` | 12 | Bubble, Selection, Insertion, Merge, Quick, Heap, Counting, Radix, Bucket, Shell, Cocktail, Gnome |
| `searching/` | 8 | Linear, Binary, Jump, Interpolation, Exponential, Ternary, Fibonacci, Binary-on-rotated-array |
| `graph/` | 14 | BFS, DFS, Dijkstra, Bellman-Ford, Floyd-Warshall, Kruskal, Prim, Topological sort, Kosaraju/Tarjan SCC, cycle detection (directed/undirected), A*, bipartite check |
| `math/` | 12 | GCD, LCM, Sieve of Eratosthenes, fast modular exponentiation, primality, factorial, permutations/combinations counts, Pascal's triangle, Armstrong/perfect numbers, prime factorization |
| `dp/` | 14 | Fibonacci, 0/1 and unbounded knapsack, LCS, LIS, edit distance, coin change (min coins / ways), matrix chain multiplication, subset sum, partition problem, rod cutting, Kadane's max subarray, egg dropping |
| `strings/` | 10 | KMP, Rabin-Karp, Z-algorithm, longest palindromic substring, anagram/palindrome checks, reversal, longest common prefix, run-length encoding, wildcard matching |
| `datastructures/` | 14 | Singly/doubly linked list, array-backed stack/queue, circular queue, min/max heap, BST, AVL tree (real rotations), trie, union-find, segment tree, Fenwick tree (BIT), LRU cache |
| `backtracking/` | 12 | N-Queens, Sudoku solver, permutations/subsets generators, rat-in-a-maze, word search, combination sum, generate parentheses, power set, Hamiltonian path, graph coloring, knight's tour |
| `misc/` | 4 | Two-pointer sum on sorted array, max-sum sliding window, Dutch national flag sort, max product subarray |

Every file has a comment above the class explaining what the algorithm does, how it
works, and its time/space complexity, plus a `main` that runs it on sample data and
prints the result. All 100 were individually compiled and run to confirm correct output
before being left here; verified again by compiling the whole tree together (no
duplicate class names, no package issues) — 108 `.class` files (some have inner
classes, e.g. linked-list/tree nodes) from 100 sources, zero errors.
