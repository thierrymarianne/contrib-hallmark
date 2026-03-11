= Logic Programming with Prolog <sec-prolog>

The previous section established Horn clauses as a tractable fragment
of first-order logic.
Prolog @wielemaker2012swi is a programming language that takes this
idea to its logical conclusion: a program _is_ a set of Horn clauses,
and running it means searching for a proof.

== Programs as Clauses

A Prolog program consists of _facts_ and _rules_, written in a
notation that mirrors the logical formulas directly.

A fact asserts that a predicate holds for specific arguments:

```prolog
parent(alice, bob).
parent(bob, charlie).
```

A rule states that its head holds whenever its body is satisfied.
The symbol `:-` reads "if":

```prolog
grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
```

The rule mirrors the Horn clause
$"parent"(x, y) and "parent"(y, z) arrow.r.double "grandparent"(x, z)$
in Prolog syntax.
Uppercase names are variables; they are implicitly universally
quantified over the entire clause.

== Backward Chaining

Given a set of clauses and a _query_ (a goal to prove), Prolog
searches for a proof using _backward chaining_:
it starts from the goal and works backwards toward known facts.

Consider the query:

```prolog
?- grandparent(alice, charlie).
```

Prolog proceeds as follows:

+ The goal `grandparent(alice, charlie)` matches the head of the rule.
  Prolog _unifies_ the goal with the head, binding
  `X = alice` and `Z = charlie`.
  The body becomes the new set of sub-goals:
  `parent(alice, Y), parent(Y, charlie)`.

+ The first sub-goal, `parent(alice, Y)`, unifies with the fact
  `parent(alice, bob)`, binding `Y = bob`.

+ The second sub-goal, `parent(bob, charlie)`, unifies with the
  corresponding fact.

+ All sub-goals are resolved. The query succeeds.

The search is _goal-directed_: Prolog only explores rules relevant
to the query, rather than blindly deriving all possible consequences.

Note that the program above is deliberately minimal.
A realistic model would include additional rules — for instance, that
a parent is necessarily distinct from its child
(`parent(X, Y) :- dif(X, Y), ...`), or that the ancestry relation
is acyclic.
Prolog does not enforce such constraints unless they are stated
explicitly; the programmer bears full responsibility for the
completeness and coherence of the clause set.
This makes backward chaining efficient when the goal space is small
relative to the fact base.

== Unification

_Unification_ is the mechanism that makes backward chaining work.
Two terms unify if there exists a _substitution_ — an assignment of
values to variables — that makes them identical.

For example, `parent(alice, Y)` and `parent(alice, bob)` unify under
the substitution `Y = bob`.
But `parent(alice, Y)` and `parent(bob, Z)` do not unify, because
`alice` and `bob` are distinct constants.

Unification is more powerful than simple pattern matching: it works
in both directions.
The term `f(X, b)` unifies with `f(a, Y)` under `X = a, Y = b` —
both terms contribute information.

== Backtracking

When multiple clauses match a goal, Prolog tries them in order.
If a choice leads to a dead end — a sub-goal that cannot be
satisfied — Prolog _backtracks_: it undoes the most recent variable
bindings and tries the next matching clause.

This systematic exploration ensures that Prolog finds all solutions
if asked, and that it does not miss valid derivations.
The search is depth-first, which makes it memory-efficient but means
that non-termination is possible if the clause structure contains
cycles.

== Prolog as a Rules Engine

Putting it all together, a Prolog program is a _backward-chaining
rules engine_ by construction:

- The *knowledge base* is the set of facts and rules (Horn clauses).
- A *query* is the goal to evaluate.
- The *inference mechanism* is SLD resolution: unification plus
  backtracking over the clause database.

No additional framework is needed.
Any set of Horn clauses, loaded into a Prolog interpreter, immediately
becomes an executable inference engine.

A remarkable property — but one that comes with a caveat:
Prolog guarantees nothing about the _correctness_ of the clauses
themselves.
If the rules are contradictory, incomplete, or ill-formed, Prolog will
happily execute them and produce wrong or unexpected answers.

The question, then, is whether we can write rules in a system that
_does_ guarantee their logical integrity, and then compile them into
Prolog for execution.
Rocq and its type system provide exactly that.
