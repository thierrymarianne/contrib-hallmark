#pagebreak()

= Reusable Proofs via Typeclasses <sec-reusable-proofs>

The properties presented in @sec-proofs — decidability,
completeness, confluence, monotonicity, bounded depth — are proved
for a specific predicate.
But the proof patterns are largely the same across different rule
sets: induction on the derivation, case analysis on constructors,
appeal to properties of the auxiliary predicates.

Rocq's typeclass mechanism lets us capture these patterns as
_generic proof frameworks_ that can be instantiated for any
predicate meeting the right structural conditions.

== Property Typeclasses

Each property becomes a typeclass.
An instance for a specific predicate witnesses that the property
holds:

```coq
Class DecidablePred {A : Type} (P : A -> Prop) := {
  dec_pred : forall x, {P x} + {~ P x};
}.

Class Complete {A : Type} (I S : A -> Prop) := {
  sound    : forall x, I x -> S x;
  complete : forall x, S x -> I x;
}.

Class Deterministic {A B : Type} (P : A -> B -> Prop) := {
  det : forall x y1 y2, P x y1 -> P x y2 -> y1 = y2;
}.

Class Monotone {F A : Type} (P : F -> A -> Prop) := {
  mono : forall (f1 f2 : F -> Prop),
    (forall x, f1 x -> f2 x) ->
    forall a, P f1 a -> P f2 a;
}.
```

These typeclasses are small — one or two fields each.
Their power comes from _composition_.

== Composing Decidability

Consider a predicate `authorized` that depends on `authenticated`
and `has_permission`.
If both auxiliaries are decidable, and the recursion through
`delegate` is well-founded, then `authorized` is decidable.

The structural requirement — well-foundedness of the recursion —
is itself captured as a typeclass:

```coq
Class WellFoundedRel {A : Type} (R : A -> A -> Prop) := {
  wf_rel : well_founded R;
}.
```

The decidability instance for `authorized` then reads:

```coq
Instance authorized_decidable
  `{DecidablePred authenticated}
  `{DecidablePred has_permission}
  `{DecidablePred is_admin}
  `{WellFoundedRel manager_of}
  : DecidablePred (fun '(u, r) => authorized u r).
Proof.
  (* induction on well-founded relation,
     case split on each constructor,
     appeal to DecidablePred instances for premises *)
Defined.
```

The proof is written once.
Any system that supplies decidable auxiliaries and a well-foundedness
witness gets decidability of `authorized` through instance resolution
— no manual wiring required.

== Composing Completeness

Completeness is relative to a specification, so it cannot be fully
generic.
But the typeclass structure ensures that composed systems inherit
completeness from their parts.

If `authenticated` is complete w.r.t. `spec_authenticated`, and
`authorized` is complete w.r.t. `spec_authorized`, and the
specifications reference each other the same way the inductives do,
then a combined completeness instance assembles naturally:

```coq
Instance authorized_complete
  `{Complete authenticated spec_authenticated}
  `{Complete has_permission spec_has_permission}
  : Complete authorized spec_authorized.
Proof.
  (* soundness: induction on derivation,
     rewrite using 'sound' from sub-instances.
     completeness: induction on spec,
     rewrite using 'complete' from sub-instances. *)
Defined.
```

When `authenticated` is later refined or replaced, only its own
`Complete` instance needs updating.
The `authorized` instance re-typechecks automatically against the
new version.

== Composing Determinism

Determinism composes particularly well.
If every auxiliary predicate is deterministic and the constructors
have non-overlapping patterns, then the whole predicate is
deterministic:

```coq
Instance authorized_deterministic
  `{Deterministic authenticated}
  `{Deterministic has_permission}
  : Deterministic authorized.
Proof.
  (* case analysis: two derivations of authorized u r
     must use the same constructor (non-overlap),
     then appeal to Deterministic instances for
     each premise to conclude equality. *)
Defined.
```

The non-overlap condition is domain-specific — the proof must show
that no two constructors can apply simultaneously.
But the recursive structure is handled uniformly by the typeclass
chain.

== Advantages over Module Functors

Rocq also supports module functors — modules parameterized by a
module type — which could serve a similar purpose.
Typeclasses are preferable here for three reasons:

- *Automatic resolution.*
  Instance search wires dependencies without explicit functor
  application.
  When `authorized` depends on `authenticated`, the solver chains
  their instances automatically.

- *Fine-grained composition.*
  Each property is an independent typeclass.
  A predicate can be `DecidablePred` without being `Deterministic`,
  and the constraint is tracked at each use site.
  Module functors bundle properties into monolithic signatures.

- *Hallmark integration.*
  The pipeline already uses `Emittable` as its bridge typeclass
  (@sec-clp).
  Adding `DecidablePred`, `Deterministic`, and `Complete` to the same
  ecosystem means the translator and the proof infrastructure share a
  unified architecture: instance resolution drives both code
  generation and proof composition.
