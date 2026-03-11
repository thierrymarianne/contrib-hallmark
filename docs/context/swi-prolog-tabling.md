# SWI-Prolog Tabling Mechanism

Technical context for Hallmark (Rocq inductives → Prolog compilation). Covers the termination problem in Prolog, SWI-Prolog tabling, termination guarantees, negation, and practical patterns.

**Sources:**
- [SWI-Prolog Tabled execution (SLG resolution)](https://www.swi-prolog.org/pldoc/man?section=tabling)
- [SWI-Prolog table/1](https://www.swi-prolog.org/pldoc/man?predicate=table/1)
- [SWI-Prolog tabling-non-termination](https://www.swi-prolog.org/pldoc/man?section=tabling-non-termination)
- [SWI-Prolog Well Founded Semantics](https://www.swi-prolog.org/pldoc/man?section=WFS)
- [SWI-Prolog tnot/1](https://www.swi-prolog.org/pldoc/man?predicate=tnot/1)
- [SWI-Prolog Variant and subsumptive tabling](https://www.swi-prolog.org/pldoc/man?section=tabling-subsumptive)
- [SWI-Prolog Answer subsumption / mode directed tabling](https://www.swi-prolog.org/pldoc/man?section=tabling-mode-directed)
- [SWI-Prolog About the tabling implementation](https://www.swi-prolog.org/pldoc/man?section=tabling-about)
- [SWI-Prolog Monotonic tabling](https://www.swi-prolog.org/pldoc/man?section=tabling-monotonic)
- [SWI-Prolog Incremental tabling](https://www.swi-prolog.org/pldoc/man?section=tabling-incremental)
- [SWI-Prolog tabling-memoize](https://www.swi-prolog.org/pldoc/man?section=tabling-memoize)

---

## 1. The Termination Problem in Prolog

### 1.1 SLD Resolution

**SLD resolution** (Selective Linear Definite clause resolution) is Prolog's basic inference rule. It is sound and refutation-complete for Horn clauses.

- **Selection rule**: Prolog uses **left-to-right** selection — goals are processed from left to right.
- **Depth-first search**: The SLD-tree is explored depth-first.
- **Clause order**: Clauses are tried top-to-bottom.

### 1.2 Left-Recursion Causes Infinite Loops

Left-recursion occurs when the recursive call is the **leftmost** goal in a clause body. Under SLD, the leftmost goal is always selected first, so the recursive call is chosen before any base case can be reached.

**Example** (transitive closure):

```prolog
path(N, M) :- path(N, Z), edge(Z, M).
path(N, M) :- edge(N, M).
```

The leftmost `path(N, Z)` is selected repeatedly, creating infinite branches in the SLD-tree that never reach the base case.

**Indirect left-recursion** also causes loops (e.g. in DCGs when `non_letters` and `word` can both match empty input, leading to recursion without consuming input).

### 1.3 Well-Founded Logic Can Still Diverge

- An SLD-tree may contain **infinite branches** even when the logic is well-founded.
- The order of clause search (top-to-bottom) and left-to-right goal selection determine whether answers are found.
- Taking left branches at every node can lead to infinite loops, while taking right branches might find solutions.
- The same logical specification can terminate or diverge depending on clause order and goal placement.

### 1.4 Typical Workarounds Without Tabling

- Reorder clauses to place base cases first.
- Convert to tail-recursive form.
- Use constraint-based approaches or cycle detection.
- Manually stratify: base layer (raw facts), intermediate layer (symmetry), final layer (transitivity with visited-set tracking).

---

## 2. SWI-Prolog Tabling (`table/1`)

### 2.1 Declaration Syntax

```prolog
:- table pred/arity.
:- table edge/2, statement//1.
```

**With options** (comma-list):

```prolog
:- table p/1 as subsumptive.
:- table (q/1, r/2) as subsumptive.
:- table connection(_,_,lattice(shortest/3)).
```

**Options** (via `as/2`):

| Option | Description |
|--------|-------------|
| `variant` | Default. One table per call variant. |
| `subsumptive` | Reuse answers from more general tables. |
| `shared` | Shared between threads. |
| `private` | Local to calling thread. |
| `incremental` | Depends on dynamic predicates; invalidates on assert/retract. |
| `dynamic` | Often used with `incremental`. |

**Answer subsumption** (mode-directed tabling):

```prolog
:- table connection(_,_,lattice(shortest/3)).
```

Modes: `+` | `index` | `lattice(PI)` | `po(PI)` | `-` | `first` | `last` | `min` | `sum`.

### 2.2 How It Works

1. **Memoization**: Re-evaluation is avoided by caching answers, giving large performance gains.
2. **Suspension of variant calls**: When a goal calls a **variant** of itself (same predicate, same structure up to variable renaming), the call is **suspended** instead of recursing.
3. **Resumption**: Suspended calls are resumed with answers from the table as they become available.
4. **Implementation**: Uses **delimited continuations** to realise suspension. The `table/1` directive creates a wrapper that calls `start_tabling/2`; the original predicate is renamed and invoked inside the tabled context.

**Translation example** (connection/2):

```prolog
connection(A, B) :-
    start_tabling(user:connection(A, B), 'connection tabled'(A, B)).

'connection tabled'(X, Y) :- connection(X, Z), connection(Z, Y).
'connection tabled'(X, Y) :- connection(Y, X).
'connection tabled'('Amsterdam', 'Schiphol').
% ...
```

### 2.3 SLG Resolution vs SLD Resolution

| SLD | SLG (Tabling) |
|-----|---------------|
| Depth-first, left-to-right | Goal-oriented, breadth-first over subgoals |
| No memoization | Memoizes subgoals and answers |
| Left-recursion loops | Variant calls suspend; no infinite loops from left-recursion |
| Recomputes same subgoals | Reuses cached answers |

### 2.4 Monotonic Tabling

- Propagates consequences of `assert/1` without recomputing tables from scratch.
- **Only for monotonic programs** — no negation.
- Declare: `:- table p/2 as monotonic`.
- Dynamic predicates: `:- dynamic link/2 as monotonic`.
- Eager (default): asserted clauses are propagated immediately.
- Lazy: invalidates tables; re-evaluation on next access.

### 2.5 Incremental Tabling

- Maintains consistency when tabled predicates depend on **incremental dynamic** predicates.
- On assert/retract, dependent tables are **invalidated**.
- Re-evaluation happens **on demand** when invalid tables are accessed.
- Bottom-up re-evaluation; unchanged tables stop propagation.
- Declare: `:- table p/1 as incremental`, `:- dynamic d/1 as incremental`.

---

## 3. Termination Guarantees

### 3.1 When Tabling Guarantees Termination

- **Finite set of subgoals**: Tabling terminates when the set of possible call variants is **finite** (Datalog-like fragment).
- **Bounded term depth**: If all subgoals are ground or have bounded depth (no unbounded function symbols), the number of variants is finite.
- **Left-recursion**: Tabling removes infinite loops from left-recursive rules; variant calls suspend and resume with answers.

### 3.2 Connection to Bounded-Depth Proofs

- In Datalog-style programs (no function symbols, finite Herbrand base), every proof has bounded depth.
- Tabling explores the subgoal space; with finitely many variants, a fixed point is reached and evaluation stops.

### 3.3 When Tabling Does NOT Guarantee Termination

- **Infinite term depth**: Function symbols (e.g. `s(s(s(...)))`) can generate infinitely many call variants.
- **Infinite answer sets**: Predicates with infinitely many solutions can exhaust table memory.
- **Cycles with infinite paths**: Transitive closure over cyclic graphs can produce infinitely many paths; use **answer subsumption** (e.g. `lattice(shortest/3)`) to aggregate and converge.

### 3.4 Downsides of Tabling

- Memoized answers are **not** automatically invalidated when the world changes (unless incremental/monotonic).
- Answer tables consume memory.
- Tables must be explicitly abolished when needed (`abolish_all_tables/0`, etc.).

---

## 4. Interaction with Negation

### 4.1 Do Not Use `\+` or `not/1` with Tabling

- `not/1` uses cut and can yield **incomplete tables** and **incorrect results** under tabling.
- SWI-Prolog documentation: "There is no negation in SWI-Prolog's tabling. As `not/1` uses a cut, one may end up with incomplete tables and incorrect results."

### 4.2 Use `tnot/1` for Tabled Negation

```prolog
tnot(:Goal)
```

- Implements **tabled negation** and **Well-Founded Semantics**.
- The argument must be a goal associated with a **tabled** predicate.
- Requires `library(tables)` or built-in support.

### 4.3 Well-Founded Semantics (WFS)

- **Three-valued logic**: true, false, **undefined** (bottom).
- Handles programs with contradictions or multiple answer sets.
- Propagates undefined to literals that cannot be resolved otherwise.
- Produces a **residual program** explaining why an answer is undefined.

**Example** (undefined):

```prolog
:- table undefined/0.
undefined :- tnot(undefined).
```

**Example** (multiple stable models):

```prolog
:- table p/0, q/0.
p :- tnot(q).
q :- tnot(p).
```

Both `{p}` and `{q}` are stable models; the well-founded model assigns **undefined** to both.

### 4.4 Resolution of `tnot(p)` (Summary)

1. If `p` has an unconditional answer → fail.
2. Else, delay the negation; if an unconditional answer arrives later → resume with failure.
3. If at end of tabled evaluation `p` is still undecided, execute the continuation with `tnot(p)` on the delay list.
4. Conditional answers may be recorded (e.g. "answer holds if `tnot(p)`").
5. Answer completion: eliminate positive loops, propagate definite true/false, iterate to fixed point.

### 4.5 Accessing the Residual Program

- `call_residual_program(:Goal, -Program)`
- `call_delays(:Goal, -Condition)`
- `delays_residual_program(:Condition, -Program)`

### 4.6 Stratified vs Non-Stratified

- WFS handles both stratified and non-stratified programs via 3-valued logic.
- Stratified negation: simpler, single 2-valued model.
- Non-stratified: may yield undefined; residual program explains cycles through `tnot/1`.

---

## 5. Practical Patterns

### 5.1 When to Use Tabling

| Use case | Example |
|----------|---------|
| Transitive closure | `connection(X,Y) :- connection(X,Z), connection(Z,Y)` |
| Graph reachability | Same pattern; cycles handled by variant suspension |
| Recursive predicates with left-recursion | Natural logical specs that loop under SLD |
| Memoization | Fibonacci, dynamic programming |
| Datalog-style inference | Static axioms/rules, goal-oriented |

### 5.2 Variant vs Subsumptive Tabling

**Variant** (default):

- One table per call variant (`p(X)` and `p(42)` are different).
- Simpler, correct for pure programs.
- Can create many tables (e.g. `p(1)`, `p(2)`, …) and slow completion.

**Subsumptive**:

- Answers a query using answers from a **more general** table.
- `p(42)` can reuse answers from `p(_)`.
- Fewer tables, faster for enumerative queries.
- Drawbacks: more dependencies, slower completion; more expensive lookup; only correct when instances are consistent with the general query (pure programs).

```prolog
:- table p/1 as subsumptive.
```

### 5.3 Answer Subsumption (Mode-Directed Tabling)

For predicates with **many** answers (e.g. infinite paths in cyclic graphs), aggregate instead of storing all:

```prolog
:- table connection(_,_,lattice(shortest/3)).

shortest(P1, P2, P) :-
    length(P1, L1), length(P2, L2),
    (L1 < L2 -> P = P1 ; P = P2).

connection(X, Y, [X,Y]) :- connection(X, Y).
connection(X, Y, P) :-
    connection(X, Z, P0), connection(Z, Y),
    append(P0, [Y], P).
```

**Modes**: `lattice(PI)`, `po(<)`, `min`, `max`, `sum`, `first`, `last`.

**Caution**: Greedy subsumption can violate least-fixed-point semantics in some programs; see [Tabling with Sound Answer Subsumption](https://arxiv.org/pdf/1608.00787.pdf).

### 5.4 Performance Implications

| Aspect | Effect |
|--------|--------|
| Memory | Tables store all answers; can grow large |
| Variant tabling | Many tables if many call variants |
| Subsumptive tabling | Fewer tables, but more complex dependencies and completion |
| Completion | Dependent components can slow down |
| Early completion | May prevent enumerating all answers for a subgoal |

### 5.5 Table Management Predicates

- `abolish_all_tables/0` — remove all tables
- `abolish_table_subgoals/1` — remove tables for given subgoals
- `abolish_nonincremental_tables/0` — remove non-incremental tables
- `current_table/2` — inspect tables
- `untable/1` — remove tabling from a predicate

---

## 6. Relevance to Hallmark

When compiling Rocq inductives to Prolog:

- **Tabling** is the main mechanism to recover termination for left-recursive or cyclic specifications that would loop under SLD.
- **`:- table pred/arity`** should be added for inductive predicates that exhibit left-recursion or mutual recursion.
- **`tnot/1`** (not `\+`) is required for negation under tabling if the target uses well-founded semantics.
- **Datalog-like fragment**: If compiled rules stay within a finite subgoal space (e.g. ground or bounded terms), tabling provides termination guarantees.
- **Answer subsumption** may be useful when compiling to predicates with aggregation (e.g. shortest path, minimal proof).
