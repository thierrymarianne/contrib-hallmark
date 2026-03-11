# SWI-Prolog Constraint Logic Programming Extensions

## Overview

SWI-Prolog ships several CLP libraries that embed domain-specific constraint solvers into the Prolog search.
Instead of eagerly enumerating values, CLP posts constraints on variables and lets the solver prune impossible assignments before or during search, often yielding orders-of-magnitude speedups on combinatorial problems.

## CLP(FD) / CLP(Z) — Finite domains and integers

Library: `library(clpfd)` (also available as `library(clpz)` in some contexts).

- Operates over **integer variables** with finite or unbounded domains.
- Constraints: arithmetic (`#=`, `#\=`, `#<`, `#>`, `#=<`, `#>=`), combinatorial (`all_distinct/1`, `global_cardinality/2`), reification (`#<==>`, `#==>`, `#\`).
- **Domain declarations**: `X in 1..10`, `Xs ins 1..99`.
- **Labeling**: `label/1` or `labeling/2` triggers the search after constraints are posted. Options control variable/value selection heuristics (`ff`, `min`, `max`, `bisect`, etc.).
- **Global constraints**: `all_distinct/1` (more powerful than `all_different`), `sum/3`, `scalar_product/4`, `element/3`, `circuit/1`, `automaton/8`, `tuples_in/2`.
- **Reification**: any constraint can be reflected as a 0/1 variable, enabling meta-constraints like "at least 3 of these must hold."

### Typical use pattern

```prolog
:- use_module(library(clpfd)).

sudoku(Rows) :-
    length(Rows, 9),
    maplist(same_length(Rows), Rows),
    append(Rows, Vs), Vs ins 1..9,
    maplist(all_distinct, Rows),
    transpose(Rows, Columns),
    maplist(all_distinct, Columns),
    Rows = [A,B,C,D,E,F,G,H,I],
    blocks(A,B,C), blocks(D,E,F), blocks(G,H,I),
    maplist(label, Rows).

blocks([], [], []).
blocks([A,B,C|Bs1], [D,E,F|Bs2], [G,H,I|Bs3]) :-
    all_distinct([A,B,C,D,E,F,G,H,I]),
    blocks(Bs1, Bs2, Bs3).
```

## CLP(B) — Boolean constraints

Library: `library(clpb)`.

- Variables range over `{0, 1}`.
- Constraints expressed via `sat/1` with Boolean expressions: `+` (or), `*` (and), `#` (xor), `\` (not), `=:=`, `=\=`.
- `taut/2` checks if a formula is a tautology and returns the truth value.
- `labeling/1` assigns values.
- Useful for circuit verification, SAT-like problems, reliability analysis, and combinatorics.

### Example

```prolog
:- use_module(library(clpb)).

%% At least one of X, Y, Z must be true, and X implies Y.
example(X, Y, Z) :-
    sat(X + Y + Z),       % at least one
    sat(X =< Y),          % X → Y
    labeling([X, Y, Z]).
```

## CLP(Q) and CLP(R) — Rationals and reals

Libraries: `library(clpq)` (exact rationals), `library(clpr)` (floating-point reals).

- Linear arithmetic constraints over rational or real-valued variables.
- Constraints: `{X + 2*Y =< 10, X >= 0, Y >= 0}` — note the brace syntax.
- The solver uses a **Simplex-based** algorithm for linear systems.
- `maximize/1`, `minimize/1` for linear optimization.
- CLP(Q) is exact (no rounding), CLP(R) is faster but approximate.

### Example

```prolog
:- use_module(library(clpq)).

%% Find X,Y satisfying a system of linear inequalities.
solve(X, Y) :-
    { X + Y =< 10,
      2*X + Y >= 6,
      X >= 0,
      Y >= 0 }.
```

## CHR — Constraint Handling Rules

Library: `library(chr)`.

- A **rule-based** language embedded in Prolog for writing custom constraint solvers.
- Three rule types:
  - **Simplification** (`c1 \ c2 <=> Guard | Body`): replaces constraints.
  - **Propagation** (`c1, c2 ==> Guard | Body`): adds new constraints without removing old ones.
  - **Simpagation** (`c1 \ c2 <=> Guard | Body`): keeps some, removes others.
- Used to implement domain-specific solvers (temporal reasoning, type systems, spatial constraints) on top of Prolog.

### Example

```prolog
:- use_module(library(chr)).

:- chr_constraint leq/2.

reflexivity  @ leq(X, X) <=> true.
antisymmetry @ leq(X, Y), leq(Y, X) <=> X = Y.
transitivity @ leq(X, Y), leq(Y, Z) ==> leq(X, Z).
idempotence  @ leq(X, Y) \ leq(X, Y) <=> true.
```

## When to use which

| Library   | Domain              | Use case                                          |
|-----------|---------------------|---------------------------------------------------|
| CLP(FD/Z) | Integers            | Scheduling, puzzles, allocation, planning         |
| CLP(B)    | Booleans            | SAT, circuit design, set covers, reliability      |
| CLP(Q/R)  | Rationals / Reals   | Linear programming, geometry, financial models    |
| CHR       | User-defined        | Custom solvers, type checkers, domain reasoning   |

## Performance notes

- Always **post constraints before labeling** — let propagation prune the search space first.
- Use `all_distinct/1` over `all_different/1`: it applies stronger arc-consistency propagation.
- For CLP(FD), choosing the right labeling strategy matters: `ff` (first-fail, smallest domain first) is a good default.
- CHR rules fire eagerly; ordering and idempotence guards are important to avoid infinite propagation loops.
