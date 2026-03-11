# Prolog

## Overview

Prolog (Programming in Logic) is a logic programming language rooted in first-order predicate logic.
Programs are expressed as sets of facts and rules; computation proceeds by querying those relations and searching for proofs via unification and backtracking.
Created by Alain Colmerauer and Philippe Roussel in Marseille around 1972, with theoretical foundations from Robert Kowalski.

## Core concepts

- **Facts**: ground assertions about the world (`parent(tom, bob).`).
- **Rules**: implications with a head and a body (`grandparent(X, Z) :- parent(X, Y), parent(Y, Z).`).
- **Queries**: goals submitted to the engine (`?- grandparent(tom, W).`), answered by searching for satisfying substitutions.
- **Unification**: the mechanism that matches terms, binding logic variables to values. Two terms unify if there exists a substitution making them identical.
- **Backtracking**: when a branch of the search fails, Prolog undoes bindings and tries the next alternative clause, systematically exploring the search space.
- **Horn clauses**: Prolog programs are essentially sets of Horn clauses — a restricted but decidable fragment of first-order logic.

## Execution model

1. A query is posed as a conjunction of goals.
2. Prolog selects the leftmost goal and attempts to unify it with the head of a clause (top-down, depth-first).
3. If unification succeeds, the body of the clause becomes the new set of sub-goals.
4. If it fails, Prolog backtracks to the most recent choice point.
5. A query succeeds when all goals are resolved; the accumulated substitution is the answer.

## Key features

- **Declarative semantics**: programs describe *what* holds rather than *how* to compute it. The same relation can be used in multiple directions (e.g. `append/3` can split, join, or enumerate lists).
- **Pattern matching via unification**: destructuring and construction of terms happen through the same mechanism.
- **DCGs (Definite Clause Grammars)**: syntactic sugar for writing parsers and grammars directly as Prolog rules.
- **Meta-programming**: programs can inspect and manipulate their own clauses (`assert`, `retract`, `clause/2`, `=..`).
- **Constraint Logic Programming (CLP)**: extensions like CLP(FD), CLP(R), CLP(B) integrate constraint solvers over finite domains, reals, and booleans into the search.

## Control and impurity

- **Cut (`!`)**: prunes the search tree, committing to the current branch. Used for efficiency and to encode deterministic choices, but breaks the pure logical reading.
- **Negation as failure (`\+`)**: succeeds when a goal cannot be proved. Sound only under the closed-world assumption.
- **Side effects**: I/O (`write/1`, `read/1`), assert/retract for dynamic databases, and foreign-function interfaces.

## Major implementations

| System        | Notable for                                         |
|---------------|-----------------------------------------------------|
| SWI-Prolog    | Most widely used, rich libraries, web/IDE tooling   |
| SICStus       | Commercial, strong CLP and performance              |
| GNU Prolog    | Native compilation, built-in CLP(FD)                |
| XSB           | Tabling (memoization), HiLog                        |
| Scryer Prolog | Modern, ISO-conformant, written in Rust             |
| Trealla       | Lightweight, ISO-conformant, embeddable             |

## ISO Standard

ISO/IEC 13211-1 (1995) standardizes core Prolog: syntax, built-in predicates, arithmetic, I/O, error handling.
Compliance varies across implementations; SWI-Prolog and Scryer aim for close conformance.

## Typical application domains

- **Symbolic AI and expert systems**: knowledge representation, rule engines, planning.
- **Natural language processing**: DCGs for parsing, semantic analysis.
- **Databases and querying**: Datalog (a subset of Prolog) underpins deductive databases.
- **Compilers and static analysis**: type inference, program transformation, abstract interpretation.
- **Formal verification**: model checking, theorem proving front-ends.
- **Combinatorial search**: scheduling, puzzles, constraint satisfaction via CLP.

## Relation to logic and other paradigms

- Prolog operationalizes **SLD resolution** (Selective Linear Definite clause resolution), a proof procedure for Horn clauses.
- **Datalog** restricts Prolog to function-free clauses, guaranteeing termination and enabling bottom-up evaluation.
- **Answer Set Programming (ASP)** generalizes logic programming with stable model semantics, better suited for non-monotonic reasoning.
- **miniKanren** embeds relational programming in functional languages (Scheme, Clojure, etc.), offering a purer but more minimalist alternative.
- Prolog's search mechanism influenced **constraint programming** and **logic-functional** hybrid languages (Curry, Mercury).
