#pagebreak()

= Tabling and Termination <sec-tabling>

Prolog's depth-first search is both its greatest practical strength
and its most dangerous limitation.
A left-recursive rule — one where the recursive call is the first
subgoal — sends the engine into an infinite loop, even when the
underlying logic is perfectly well-founded.

```prolog
path(X, Y) :- path(X, Z), edge(Z, Y).
path(X, Y) :- edge(X, Y).
```

The first clause calls `path` before any base case can be reached.
Under standard SLD resolution, the engine re-enters the same goal
indefinitely, never progressing to the second clause.

This appendix introduces _tabling_, a mechanism available in
SWI-Prolog that eliminates this class of divergence and connects
directly to the bounded-depth proofs from @sec-proofs.
Tabling is not currently emitted by Hallmark; the material below
describes what a tabling extension could look like and why it would
be a natural fit for the system.

== SLG Resolution and Memoization

Tabling replaces Prolog's standard depth-first search (SLD
resolution) with _SLG resolution_, which memoizes subgoals and
their answers.

The idea is straightforward:

+ When a tabled predicate is called for the first time with a
  given pattern of arguments (a _call variant_), the engine
  creates a table entry for that variant and begins computing
  answers.

+ When the same variant is encountered again during the
  computation — as happens in a left-recursive rule — the engine
  _suspends_ the recursive call instead of re-entering it.

+ As new answers are added to the table, suspended calls are
  _resumed_ with those answers, producing further derivations.

+ The process reaches a _fixed point_ when no new answers can be
  produced.
  At that point, every suspended call is resolved and the table
  is complete.

The declaration is a single directive:

```prolog
:- table path/2.

path(X, Y) :- path(X, Z), edge(Z, Y).
path(X, Y) :- edge(X, Y).
```

With tabling, the left-recursive `path` terminates on any finite
graph.
The engine collects all reachable pairs without entering an
infinite loop.

== Connection to Bounded-Depth Proofs

Recall from @sec-proofs that one can prove a bound on the depth
of any derivation:

```coq
Theorem allowed_bounded :
  forall u r (d : allowed u r),
    depth u r d <= max_chain_length.
```

This proof establishes that the set of subgoals encountered
during any derivation of `allowed` is finite — bounded by the
structure of the management hierarchy.
When the subgoal set is finite, tabling _guarantees_ termination:
every variant is tabled at most once, and the fixed-point
computation must converge.

A tabling extension could exploit this directly.
When a bounded-depth proof exists for an inductive predicate,
the translator could automatically emit a tabling directive:

```prolog
:- table allowed/2.
```

The Rocq proof would become a _justification_ for the Prolog-level
optimization: the bounded-depth theorem certifies that tabling
will terminate, and the directive makes Prolog enforce it.

== The Datalog Fragment

Tabling is most powerful for the _Datalog_ fragment of logic
programming: programs without function symbols, where all terms
are constants or variables.
In this fragment, the Herbrand universe is finite, every predicate
has finitely many possible ground instances, and tabling
guarantees termination for all queries.

Many rule sets compiled by Hallmark fall naturally into this
fragment.
Access-control policies, eligibility checks, and classification
rules typically operate over finite enumerations (users,
resources, roles) without constructing new terms.
For these programs, tabling provides _complete_ evaluation:
every derivable answer is found, and the search always terminates.

When function symbols are present — for instance, natural numbers
built from `O` and `S`, or lists built from `cons` — the Herbrand
universe may be infinite, and tabling alone does not guarantee
termination.
In such cases, the bounded-depth proof from Rocq remains
essential: it provides the guarantee that tabling cannot.

== Tabling and Negation

Tabling interacts productively with the negation mechanism
from @sec-negation.
Standard negation-as-failure (`\+`) requires the negated goal to
finitely fail, but under SLD resolution, this is difficult to
guarantee for recursive predicates.

SWI-Prolog provides `tnot/1`, a tabled variant of negation that
implements _well-founded semantics_:

```prolog
:- table safe_allowed/2.

safe_allowed(U, R) :-
    allowed(U, R),
    tnot(revoked(U, R)).
```

Where `\+` would attempt to prove `revoked(U, R)` by depth-first
search (risking divergence), `tnot` consults the table:
if `revoked(U, R)` has no unconditional answer in the completed
table, the negation succeeds.

Well-founded semantics extends the two-valued model (true/false)
to three values: _true_, _false_, and _undefined_.
A goal is undefined when it depends on its own negation through a
cycle that cannot be resolved.
For stratified programs (those handled by @sec-negation), well-founded
semantics coincides with the stratified model — every answer is
true or false, never undefined.
For non-stratified programs, it provides the most cautious
well-defined semantics, reporting cycles as undefined rather than
giving incorrect answers.

== Running Example: Cyclic Delegation

Consider a delegation graph that contains a cycle:

```prolog
manager_of(alice, bob).
manager_of(bob, alice).
```

Without tabling, the query `allowed(alice, secret_report)` loops
forever: `delegate` chains through `manager_of`, alternating
between Alice and Bob without bound.

With tabling:

```prolog
:- table allowed/2.

allowed(admin, R).
allowed(U, public_doc).
allowed(U, R) :- manager_of(U, V), allowed(V, R).
```

the engine recognizes that `allowed(alice, secret_report)` and
`allowed(bob, secret_report)` are call variants it has already
seen.
The suspended calls are resumed with any answers from the table;
since neither Alice nor Bob is `admin`, no answers are produced,
and the query correctly fails.

The bounded-depth proof in Rocq would have detected that the
management hierarchy is _not_ acyclic in this configuration,
signaling to the user that either the data is inconsistent or the
rules need a cycle guard.
Tabling ensures that even without such a guard, the engine
terminates gracefully rather than diverging.

== When Tabling is Insufficient

Tabling does not solve all termination problems.
Two cases remain outside its reach:

- *Infinite term depth.*
  When constructors build nested terms (e.g., `S (S (S ...))` for
  natural numbers), each level of nesting creates a new call
  variant.
  The set of variants is infinite, and tabling cannot converge.

- *Infinite answer sets.*
  A predicate with infinitely many solutions may exhaust memory
  even if it terminates logically.

In both cases, the bounded-depth proofs from @sec-proofs are the
appropriate tool: they provide a Rocq-level guarantee that the
derivation space is finite, independent of Prolog's execution
strategy.
Tabling and bounded-depth proofs are complementary —
tabling handles the execution mechanism, while the proof handles
the logical structure.
