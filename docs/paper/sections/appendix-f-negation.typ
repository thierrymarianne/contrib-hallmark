#pagebreak()

= Negation and Stratification <sec-negation>

The Horn clauses presented so far are _definite_: each rule
establishes that something holds, never that something does not.
Yet many real-world rule sets require negation —
an access-control policy may deny access when a credential has been
revoked, or grant access only when no conflict of interest exists.

This appendix first describes what the current implementation
provides, then sketches the richer design that would be needed to
handle negation soundly.

== Negation-as-Failure in Prolog

Prolog implements negation through a mechanism called
_negation-as-failure_ (NAF), written `\+ Goal`.
The semantics is simple: `\+ Goal` succeeds when `Goal`
_finitely fails_ — when the search space for `Goal` is exhausted
without finding a proof.

This rests on the _closed-world assumption_: what cannot be proved
from the program is assumed to be false.
The assumption is pragmatic — in a self-contained rule set,
the absence of a derivation is meaningful — but it carries a
soundness condition.

NAF is sound only when the negated goal is _ground_ at evaluation
time (all variables are bound to concrete values).
When variables remain free, Prolog's evaluation may produce
incorrect answers: `\+ p(X)` fails if `p` has _any_ solution,
even though the intended reading might be "there exists an `X`
for which `p` does not hold."

== Negation in Rocq

In the Calculus of Inductive Constructions, negation is defined as:

```coq
Definition not (P : Prop) := P -> False.
```

A proof of `~P` is a function that takes any hypothetical proof of
`P` and produces a contradiction.
This is _constructive_ negation: to refute `P`, one must show that
`P` leads to an impossibility.

Constructive negation is strictly weaker than classical negation —
the law of excluded middle ($P or not P$) is not provable in
general.
The bridge between the two worlds is _decidability_:

```coq
Class Decidable (P : Prop) :=
  decide : {P} + {~ P}.
```

A `Decidable` instance is a decision procedure: for every input it
terminates and returns either a proof of `P` or a proof of `~P`.
When such a proof exists for the negated goal, the corresponding
Prolog evaluation is guaranteed to either succeed or finitely fail
on ground inputs — exactly the condition under which NAF is sound.

== Current Behaviour: Failure Diagnosis

The current implementation does not translate any `~P` constructor
premise into a `\+` goal.
A constructor containing a negation is treated as an ordinary
anonymous binder and classified as `BExternal`, producing a plain
Prolog atom that will simply fail at runtime unless a matching fact
is provided externally.

What the implementation _does_ provide is a failure-diagnosis
subcommand.
The `hallmark why-not` CLI command answers the question: _given
that this query failed, why?_
It builds a failure tree by enumerating every clause whose head
matches the goal and recursively identifying the first body subgoal
that failed:

```prolog
why_not(Goal, fail_node(Goal, Reason)) :-
    findall(rule_attempt(Rule, Rest),
            (clause(Goal, Body), body_rule(Body, Rule, Rest)),
            Attempts),
    (   Attempts == []
    ->  Reason = no_clause
    ;   maplist(try_rule_not, Attempts, Results),
        Reason = all_rules_failed(Results)
    ).
```

The result is a labelled tree that identifies, for each failing
rule, the first subgoal responsible.
This is a diagnostic tool for query debugging, not a mechanism for
compiling negation from Rocq.

== The Desired Design

A sound negation extension would connect the Rocq and Prolog sides
through `Decidable` instances.
The desired design has three components.

=== Detecting Negated Premises

During Stage 2, when the translator encounters an anonymous binder
of type `~P`, it would check whether `P` carries a `Decidable`
instance.
If so, the binder is classified as a negated premise and emitted as
`\+ p(args)` in the clause body.
If no `Decidable` instance exists, the translator rejects the
definition with a compile-time error, preventing an unsound `\+`
from being emitted silently.

For example, the constructor:

```coq
Inductive safe_allowed : user -> resource -> Prop :=
  | safe_grant : forall u r,
      allowed u r ->
      ~ revoked u r ->
      safe_allowed u r.
```

would generate:

```prolog
safe_allowed(U, R) :-
    rule(safe_grant), allowed(U, R), \+ revoked(U, R).
```

provided that `revoked` carries a `Decidable` instance.
Without one, the translation would fail at the Rocq elaboration
step.

=== Stratification Check

Negation introduces a second concern: if predicate `p` depends
negatively on `q` and `q` depends negatively on `p`, the program
has no well-defined meaning.
The standard remedy is _stratification_ — organizing predicates
into layers such that negation only crosses layers downward.

Formally, a program is stratified if there exists an assignment
of levels to predicates such that:

- If `p` appears positively in a clause defining `q`, then
  $"level"(p) <= "level"(q)$.
- If `p` appears _negated_ in a clause defining `q`, then
  $"level"(p) < "level"(q)$.

Stratified programs have a unique _perfect model_ — the semantics
is unambiguous.
After emitting clauses, the desired translator would build a
dependency graph and reject any program whose graph contains a
cycle passing through a negative edge.
Rocq's strict positivity condition already prevents an inductive
type from negating itself, so violations can only arise when
composing multiple inductives; the check would catch exactly those
cases.

=== Preserving Guarantees

Under this design, every `\+` in the generated program would
correspond to a `~P` premise backed by a `Decidable` proof.
The Prolog evaluation would faithfully mirror the Rocq semantics:
the goal succeeds or finitely fails, with no undetermined case.
Stratification would ensure a unique stable model, preventing
circular reasoning through negation.
All positive properties proved about the underlying predicates
(@sec-proofs) would remain valid, since the negation layer adds
new predicates without modifying the existing ones.
