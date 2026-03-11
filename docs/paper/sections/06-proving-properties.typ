= Proving Properties of the Rules <sec-proofs>

The previous section showed that Rocq's type-checker automatically
enforces well-foundedness, consistency, and type correctness on any
inductive definition.
These are valuable but generic — they hold for every well-typed
inductive, regardless of its intended meaning.

Rocq goes much further.
Once an inductive predicate is defined, it becomes a first-class
mathematical object: the subject of lemmas, theorems, and proofs
carried out with the full power of the Calculus of Inductive
Constructions.
The user can state and prove _domain-specific_ properties that
capture exactly what the rules are supposed to do — and the
machine checks every step.

We illustrate this on the `allowed` access-control policy introduced
earlier.

== Decidability

A fundamental question for any rules engine is: _does every query
terminate with a definite answer?_
In Prolog, the depth-first search may loop forever on recursive rules.
In Rocq, one can prove that this cannot happen for a given definition.

```coq
Lemma allowed_decidable :
  forall u r, {allowed u r} + {~ allowed u r}.
```

The type `{P} + {~ P}` is a _decidable proposition_: it demands a
constructive witness — either a proof that `allowed u r` holds, or a
proof that it does not.
There is no middle ground; the mere statement forces the proof to
account for every case.

The proof proceeds by well-founded induction on the management
hierarchy.
Because `delegate` can only recurse through a `manager_of` relation,
and the hierarchy is finite, the recursion is bounded.
Each branch of the case analysis either produces a derivation of
`allowed u r` or shows that no derivation exists.

Once this lemma is proved, any Prolog engine running the generated
clauses is guaranteed to terminate on all inputs — a property that
testing alone could never establish.

== Completeness Relative to a Specification

A rules engine should accept exactly the right inputs — no more,
no less.
To state this precisely, one defines a _reference specification_
as a separate predicate capturing the intended semantics, then proves
equivalence with the inductive definition.

```coq
Definition spec_allowed (u : user) (r : resource) : Prop :=
  u = admin
  \/ r = public_doc
  \/ exists v, manager_of u v /\ spec_allowed v r.

Theorem allowed_complete :
  forall u r, allowed u r <-> spec_allowed u r.
```

The forward direction ($arrow.r.double$) is _soundness_: every
derivation in the engine corresponds to a case in the specification.
The backward direction ($arrow.l.double$) is _completeness_: every
case in the specification is reachable by the engine.

The proof typically proceeds by induction on the derivation
(for soundness) and on the specification structure (for completeness),
matching each constructor to its corresponding clause in the spec.

This kind of theorem is especially valuable when the inductive
definition is optimized or refactored.
The specification serves as a stable reference — any change to the
rules that breaks the equivalence is immediately caught by the
type-checker.

== Confluence

When a rules engine admits multiple derivation paths for the same
goal, a natural concern is whether all paths lead to the same
conclusions.
_Confluence_ guarantees that the order in which rules are applied
does not affect the final result.

For a deterministic predicate — one where each valid input has exactly
one possible derivation — confluence is trivial.
For predicates with overlapping rules, it requires proof.

```coq
Theorem allowed_confluence :
  forall u r (d1 d2 : allowed u r),
    d1 = d2.
```

This statement says that any two derivations of the same judgment
`allowed u r` are equal — there is at most one way to derive any
given conclusion.
The property is known as _proof irrelevance_ for the predicate.

When the predicate is not proof-irrelevant (multiple distinct
derivations exist), one can instead prove a weaker form: all
derivations agree on their observable output.

```coq
Theorem allowed_deterministic :
  forall u r1 r2,
    allowed u r1 -> allowed u r2 -> r1 = r2.
```

== Monotonicity

A desirable property of many rule sets is _monotonicity_: adding new
facts to the knowledge base never revokes a previously derivable
conclusion.
In a non-monotonic system, learning something new can invalidate
earlier reasoning — a source of subtle bugs in production rules
engines.

For the `allowed` policy, monotonicity with respect to the
`manager_of` relation can be stated as follows:

```coq
Theorem allowed_monotone :
  forall (m1 m2 : user -> user -> Prop),
    (forall u v, m1 u v -> m2 u v) ->
    forall u r,
      allowed_with m1 u r -> allowed_with m2 u r.
```

Here, `allowed_with` is a version of `allowed` parameterized by the
management relation.
The theorem says: if `m2` extends `m1` (every fact in `m1` is also
in `m2`), then every conclusion derivable under `m1` remains
derivable under `m2`.

The proof proceeds by induction on the derivation, showing that each
rule application under `m1` can be replayed under `m2` because the
premises are preserved.

== Bounded Derivation Depth

For deployment in real-time or resource-constrained environments,
it is often necessary to guarantee that no derivation exceeds a
known depth.
This ensures that the Prolog engine terminates within a predictable
number of steps, regardless of the input.

```coq
Fixpoint depth (u : user) (r : resource) (d : allowed u r) : nat :=
  match d with
  | admin_all _     => 0
  | read_public _   => 0
  | delegate _ _ _ _ _ sub => S (depth _ _ sub)
  end.

Theorem allowed_bounded :
  forall u r (d : allowed u r),
    depth u r d <= max_chain_length.
```

The function `depth` counts the number of `delegate` applications in
a derivation.
The theorem asserts that this count is bounded by the maximum length
of a management chain — a quantity determined by the structure of the
organization, not by the rules themselves.

Combined with Prolog's depth-first search, this bound guarantees
termination within a known number of resolution steps.

Each of these proofs is checked by Rocq's kernel and holds
unconditionally once established.
These properties need not be written from scratch for every new
rule set — @sec-reusable-proofs shows how typeclasses turn them
into composable building blocks.
