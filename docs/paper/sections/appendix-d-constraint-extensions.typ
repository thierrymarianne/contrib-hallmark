#pagebreak()

= Constraint Logic Programming Extensions <sec-clp>

The Hallmark pipeline presented so far translates inductive constructors
into pure Prolog clauses — facts and rules built from atoms and
unification.
This covers a wide range of rule systems, but many real-world
specifications involve _arithmetic constraints_: age thresholds,
score bounds, counts, priorities.

SWI-Prolog's CLP(FD) library extends backward chaining with a
finite-domain constraint solver.
Rather than enumerating integer values, the engine posts constraints
on variables and propagates them, pruning the search space before
any backtracking occurs.
Hallmark supports CLP(FD) for the five standard comparison
predicates over `nat`.

== The CLP(FD) Operator Table

Hallmark does not use a typeclass or any user-extensible mechanism
for constraints.
Instead, `clpfd_defaults` in `theories/Clp.v` builds a fixed table
at elaboration time by quoting five standard comparison propositions
and recording their kernames:

#figure(
  table(
    columns: 3,
    align: (left, center, left),
    table.header[*Rocq proposition*][*Quoted kername*][*CLP(FD) operator*],
    [`n <= m`], [`Nat.le`],  [`#=<`],
    [`n < m`],  [`Nat.lt`],  [`#<`],
    [`n >= m`], [`Nat.ge`],  [`#>=`],
    [`n > m`],  [`Nat.gt`],  [`#>`],
    [`n = m`],  [`Logic.eq`],[`#=`],
  ),
  caption: [The five built-in CLP(FD) mappings.],
) <fig-clpfd-table>

Quoting is done with MetaRocq's `tmQuote` so the kernames are
resolved at elaboration time rather than hard-coded as strings.
This makes the table robust to changes in module paths across
Rocq versions.

== Classification and Emission

During Stage 2 (@sec-hallmark), `classify_binding` checks every
anonymous binder against the table.
An anonymous binder whose head kername appears in the table is
classified as `BConstraint op args` — a new binding class distinct
from `BExternal`.

During emission, a `BConstraint` binding becomes a `PConstraint`
node in the internal IR, which the pretty-printer renders as:

```prolog
clpfd_check(L op R)
```

The `clpfd_check/1` wrapper is defined at the top of the generated
file:

```prolog
:- meta_predicate clpfd_check(0).
clpfd_check(C) :- call(C).
```

It exists solely to make the constraint callable via `call/1` in
the meta-interpreter; at the solver level it is transparent.

The emitter also detects whether any clause in the program uses a
`PConstraint` node.
If so, it prepends `:- use_module(library(clpfd)).` to the output
automatically — no annotation is required from the user.

== A Concrete Example

The `eligible` predicate from `examples/Eligible.v` combines a
trusted external predicate with CLP(FD) bounds:

```coq
Inductive eligible : person -> nat -> Prop :=
  | senior : forall p age,
      age_of p age -> 65 <= age -> eligible p age
  | minor  : forall p age,
      age_of p age -> age < 18 -> eligible p age.
```

The premise `65 <= age` is an anonymous binder whose type is
`Nat.le 65 age`.
`classify_binding` finds `Nat.le` in the table, records the operator
`#=<` and the argument list `[65, age]`, and emits
`clpfd_check(65 #=< Age)`.
Similarly, `age < 18` becomes `clpfd_check(Age #< 18)`.

The complete generated output is:

```prolog
:- use_module(library(clpfd)).
rule(_).
eligible(X0, X1) :-
    rule(senior), age_of(X0, X1), clpfd_check(65 #=< X1).
eligible(X0, X1) :-
    rule(minor), age_of(X0, X1), clpfd_check(X1 #< 18).
ctor_witness(senior, eligible(X0, X1),
    [age_of(X0, X1), clpfd_check(65 #=< X1)],
    app(senior, [X0, X1, pf(0), lia])).
ctor_witness(minor, eligible(X0, X1),
    [age_of(X0, X1), clpfd_check(X1 #< 18)],
    app(minor, [X0, X1, pf(0), lia])).
```

The `lia` atom in the `ctor_witness` argument list marks the slot
corresponding to the arithmetic premise.
During proof reconstruction, `rocq_string_arg` maps `lia` to
`ltac:(lia)`, discharging the arithmetic obligation with Rocq's
linear-arithmetic tactic rather than attempting to reconstruct it
structurally.

== Scope and Limitations

The current implementation covers only CLP(FD) and only the five
`nat` comparison predicates listed in @fig-clpfd-table.
There is no support for CLP(B) (boolean satisfiability) or CLP(Q/R)
(rational/real linear arithmetic), and the table is not
user-extensible without modifying `clpfd_defaults`.

Extending coverage to other domains or to user-defined numeric types
requires adding entries to the kername table and, on the Prolog side,
the appropriate `:- use_module` header — both mechanical changes
confined to `theories/Clp.v` and `theories/Emit.v`.

== Preserving Guarantees

The CLP(FD) extension does not weaken Hallmark's soundness properties.

- The Rocq side still type-checks the inductive definition, including
  the constraint-carrying premises.
  All properties proved about the rules (@sec-proofs) remain valid.

- The Prolog side replaces what would be an unresolvable atom with a
  CLP(FD) call that computes the same truth value — more efficiently,
  using the constraint solver instead of enumeration.

The key invariant is that the emitted constraint must be
_semantically faithful_ to the Rocq proposition: the constraint
succeeds exactly when the proposition holds.
For the five built-in operators this coincides with the standard
CLP(FD) semantics for non-negative integers.
This obligation is currently informal; a future direction is to
state it as a Rocq theorem for each entry in the table.
