#pagebreak()

= Negation and Stratification <sec-negation>

The Horn clauses presented so far are _definite_: each rule
establishes that something holds, never that something does not.
Yet many real-world rule sets require negation —
an access-control policy may deny access when a credential has been
revoked, or grant access only when no conflict of interest exists.

This section extends the Hallmark pipeline to handle negation,
using decidability proofs from Rocq to certify that the translation
is sound.

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

This distinction between safe and unsafe uses of negation is
precisely where Rocq's type system can help.

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
For Hallmark, this is precisely the right stance:
we can only emit `\+ goal` in Prolog when we _know_ that the goal
either succeeds or finitely fails, never when its status is
undetermined.

The bridge between the two worlds is _decidability_.

== The Bridge: Decidability Enables Safe Negation

Recall from @sec-proofs the decidability lemma:

```coq
Lemma allowed_decidable :
  forall u r, {allowed u r} + {~ allowed u r}.
```

The type `{P} + {~ P}` is a _decision procedure_: for every input,
it terminates and returns either a proof of `P` or a proof of
`~ P`.
When such a proof exists, the corresponding Prolog predicate is
guaranteed to either succeed or finitely fail on ground inputs —
exactly the condition under which NAF is sound.

Hallmark leverages this through the `Emittable` typeclass
introduced in @sec-clp.
When a constructor's premise is a negation `~ P` and `P` carries
a `Decidable` instance, the translator emits `\+ goal` in the
generated Prolog:

```coq
Instance emit_neg (P : Prop) `{Decidable P} :
    Emittable (~ P) := {
  emit := "\\+ " ++ emit_goal P;
}.
```

Without a decidability proof, the translator refuses to emit
negation — a compile-time guarantee that every `\+` in the
generated program is safe.

== Running Example: Revocable Access

Let us extend the `allowed` policy with a revocation mechanism.
A user's access is granted only when it has not been revoked:

```coq
Inductive revoked : user -> resource -> Prop :=
  | revoke : forall u r, blacklist u r -> revoked u r.

Instance revoked_decidable :
  forall u r, Decidable (revoked u r).
(* proof omitted — follows from the finiteness of the blacklist *)

Inductive safe_allowed : user -> resource -> Prop :=
  | safe_grant : forall u r,
      allowed u r ->
      ~ revoked u r ->
      safe_allowed u r.
```

The constructor `safe_grant` requires both a positive derivation
(`allowed u r`) and a negative one (`~ revoked u r`).
Because `revoked` is decidable, Hallmark emits:

```prolog
safe_allowed(U, R) :-
    allowed(U, R),
    \+ revoked(U, R).
```

The Prolog engine checks access first, then verifies that no
revocation exists — precisely the intended semantics.

== Stratification

Negation introduces a subtlety: if predicate `p` depends
negatively on `q` and `q` depends negatively on `p`, the program
has no well-defined meaning.
The standard remedy is _stratification_ — organizing predicates
into layers (strata) such that negation only crosses layers
_downward_.

Formally, a program is stratified if there exists an assignment
of levels to predicates such that:

- If `p` appears positively in a clause defining `q`, then
  $"level"(p) <= "level"(q)$.
- If `p` appears _negated_ in a clause defining `q`, then
  $"level"(p) < "level"(q)$.

Stratified programs have a unique _perfect model_ — the semantics
is unambiguous.

In Hallmark, the translator builds a dependency graph over the
compiled predicates, with edges labeled _positive_ or _negative_.
If the graph contains a cycle that passes through a negative edge,
the translation is rejected with an error.
Rocq's strict positivity condition already prevents an inductive
type from negating _itself_ in its own definition, so
stratification violations can only arise when multiple inductives
are composed.
The compile-time check catches exactly those cases.

== Preserving Guarantees

The negation extension preserves Hallmark's soundness properties:

- Every `\+` in the generated program corresponds to a `~ P`
  premise that is backed by a decidability proof.
  The Prolog evaluation faithfully mirrors the Rocq semantics:
  the goal succeeds or fails, with no undetermined case.

- Stratification ensures that the generated program has a unique
  stable model, preventing circular reasoning through negation.

- All the positive properties proved about the underlying
  predicates (@sec-proofs) remain valid.
  The negation layer adds new predicates; it does not alter the
  existing ones.

For programs that go beyond stratification — predicates with
mutually negative dependencies that do not form a strict
hierarchy — @sec-tabling introduces tabling as a mechanism
to recover well-defined semantics.
