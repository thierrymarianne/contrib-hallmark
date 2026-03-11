= Phase 4 — Property Verification <sec-phase-4>

This phase proves key properties about the `allowed` inductive in Rocq.
Every proof is intrinsically a test (Layer 1): if the file compiles, the property holds.
Additionally, where a property has computational content (decidability), we test the extracted decision procedure in Prolog (Layer 2).

== Step 4.1 — Decidability <sec-step-4-1>

Prove `forall u r, {allowed u r} + {~ allowed u r}`.
Requires decidable equality on `user` and `resource`, and decidability of `manager_of` and `public`.

*Code deliverable:* `theories/properties/Decidability.v` compiles.

*Test deliverable (L1):* The proof itself. Additionally, compute the decision procedure on concrete inputs:
```
Example admin_decidable :
  if allowed_dec admin secret_report then true else false = true
:= eq_refl.

Example stranger_decidable :
  if allowed_dec stranger secret_report then true else false = false
:= eq_refl.
```

== Step 4.2 — Completeness against a specification <sec-step-4-2>

Define `spec_allowed : user -> resource -> bool` as a reference implementation.
Prove `forall u r, allowed u r <-> spec_allowed u r = true`.

*Code deliverable:* `theories/properties/Completeness.v` compiles.

*Test deliverable (L1):*
```
Example spec_agrees_admin :
  spec_allowed admin secret_report = true := eq_refl.
Example spec_agrees_stranger :
  spec_allowed stranger secret_report = false := eq_refl.
```

== Step 4.3 — Confluence / determinism <sec-step-4-3>

Prove that if two derivations of `allowed u r` exist, they are propositionally equal.
A weaker variant: at most one constructor applies per `(u, r)` pair.

*Code deliverable:* `theories/properties/Determinism.v` compiles.

*Test deliverable (L1):* The proof itself is the test.
Add a negative test: define a deliberately non-deterministic inductive, and use `Fail` to assert the proof strategy does not go through:
```
Fail Lemma ambig_det : forall x,
  ambiguous_pred x -> ambiguous_pred x -> False.
```

== Step 4.4 — Monotonicity <sec-step-4-4>

Prove that extending the fact base preserves existing conclusions.
Parameterize `allowed` over a fact set `F` and show `allowed F u r -> allowed (F ∪ F') u r`.

*Code deliverable:* `theories/properties/Monotonicity.v` compiles.

*Test deliverable (L1):* The proof itself.
Add a computational sanity check with two fact sets:
```
Example mono_check :
  allowed_with_facts small_facts admin r ->
  allowed_with_facts big_facts admin r.
```

== Step 4.5 — Bounded derivation depth <sec-step-4-5>

Define `allowed_depth : nat -> user -> resource -> Prop` that tracks delegation chain depth.
Prove `exists n, forall u r, allowed u r -> allowed_depth n u r` given a finite `manager_of`.

*Code deliverable:* `theories/properties/BoundedDepth.v` compiles.

*Test deliverable (L1):*
```
Example depth_bound :
  max_delegation_depth = 3 := eq_refl.
```

== Step 4.6 — Reusable proof typeclasses <sec-step-4-6>

Package properties into typeclasses:
- `DecidablePred (P : A -> B -> Prop)`.
- `Complete (P : A -> B -> Prop) (spec : A -> B -> bool)`.
- `Deterministic (P : A -> B -> Prop)`.
- `Monotone (P : FactSet -> A -> B -> Prop)`.

Register instances for `allowed`.

*Code deliverable:* `theories/properties/Classes.v` and instance registrations compile.

*Test deliverable (L1):* Assert that resolution finds the instances automatically:
```
Example auto_decidable :
  DecidablePred allowed := _.

Example auto_complete :
  Complete allowed spec_allowed := _.
```
The underscore forces Rocq's typeclass resolution to find the instance; failure to resolve is a compilation error.
