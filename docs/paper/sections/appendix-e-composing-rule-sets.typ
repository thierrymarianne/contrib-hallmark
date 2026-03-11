#pagebreak()

= Composing Rule Sets <sec-composition>

The examples so far have involved a single inductive predicate
compiled in isolation.
Real-world rule systems are rarely so simple: an insurance engine
juggles `eligible`, `covered`, `excluded`, and `requires_review`;
a medical system cross-references `indicated`, `contraindicated`,
and `requires_monitoring`.
These predicates form a dependency graph, and Hallmark must handle
the graph as a whole.

Two complementary mechanisms address this:
_mutual inductives_ for predicates that genuinely co-depend,
and _parameterization_ for predicates that should remain independent
and composable.
Knowing when to use each is a design decision with direct consequences
on modularity, provability, and reuse.

== Mutual Inductives

Rocq supports _mutual inductive definitions_: several predicates
defined in a single block, where each constructor may refer to any
predicate in the block.

Consider an access-control system where authentication and
authorization depend on each other:

```coq
Inductive authenticated : user -> session -> Prop :=
  | auth_password : forall u s,
      valid_credentials u ->
      fresh_session s ->
      authenticated u s
  | auth_delegated : forall u v s,
      manager_of u v ->
      authenticated v s ->
      authenticated u s

with authorized : user -> resource -> Prop :=
  | auth_admin : forall u r,
      is_admin u -> authorized u r
  | auth_session : forall u r s,
      authenticated u s ->
      has_permission u r ->
      authorized u r
  | auth_delegate : forall u v r,
      manager_of u v ->
      authorized v r ->
      authorized u r.
```

The `with` keyword ties the two predicates into a single mutual
block.
Rocq checks well-foundedness for the block as a whole, ensuring
that the mutual recursion between `authenticated` and `authorized`
is structurally sound.

=== Translation

When Hallmark quotes a mutual inductive via MetaRocq, the AST
contains a `mutual_inductive_body` — a list of
`one_inductive_body` entries sharing a common context.
The translator iterates over all entries and emits clauses for
each predicate.

The generated Prolog is simply the union of all clauses:

```prolog
% Mutual block: authenticated, authorized

authenticated(U, S) :-
    valid_credentials(U), fresh_session(S).
authenticated(U, S) :-
    manager_of(U, V), authenticated(V, S).

authorized(U, R) :- is_admin(U).
authorized(U, R) :-
    authenticated(U, S), has_permission(U, R).
authorized(U, R) :-
    manager_of(U, V), authorized(V, R).
```

Prolog does not distinguish mutual from independent predicates —
all clauses live in a flat namespace.
The mutual structure matters only on the Rocq side (for
well-foundedness) and during translation (for recognizing
cross-predicate references as known atoms rather than opaque
auxiliaries).

=== Mutual Induction Principles

Proofs about mutual inductives require _mutual induction_:
to prove a property about `authenticated`, one simultaneously
proves a related property about `authorized`, and vice versa.

```coq
Scheme authenticated_ind := Induction for authenticated Sort Prop
  with authorized_ind := Induction for authorized Sort Prop.
```

Rocq generates a combined induction principle that lets each case
appeal to the induction hypothesis of the other predicate.
The proofs from @sec-proofs — decidability, completeness,
monotonicity — carry over directly, with mutual induction replacing
simple induction.

== The Limits of Mutual Inductives

Mutual blocks are the right tool when predicates _must_ co-refer:
one cannot define `authenticated` without mentioning `authorized`
in a constructor, and vice versa.

But packing predicates into the same block when they do not
genuinely co-depend has costs:

- *Rigidity.*
  All predicates in a mutual block are defined together.
  Changing one forces re-checking and recompiling the entire block.

- *Proof complexity.*
  Mutual induction principles grow combinatorially.
  A block of $k$ predicates produces an induction principle with
  $k$ properties to establish simultaneously, even if only one is
  of interest.

- *Reuse.*
  A predicate locked inside a mutual block cannot be reused
  independently in a different context or project.

The guiding principle: _use mutual inductives only when the
dependency cycle is real._
If predicate $A$ refers to $B$ and $B$ refers to $A$, a mutual
block is necessary.
If $A$ refers to $B$ but $B$ does not refer to $A$, they should
be separate.

== Parameterized Inductives

The alternative to packing everything into one block is
_parameterization_: defining each predicate independently, with
its dependencies passed in as parameters.

Consider splitting the previous example.
Authentication does not inherently depend on authorization — the
dependency ran only in one direction.
We can define `authenticated` on its own:

```coq
Inductive authenticated : user -> session -> Prop :=
  | auth_password : forall u s,
      valid_credentials u ->
      fresh_session s ->
      authenticated u s
  | auth_delegated : forall u v s,
      manager_of u v ->
      authenticated v s ->
      authenticated u s.
```

Then define `authorized` separately, with `authenticated` appearing
as an ordinary premise — not a co-defined predicate:

```coq
Inductive authorized : user -> resource -> Prop :=
  | auth_admin : forall u r,
      is_admin u -> authorized u r
  | auth_session : forall u r s,
      authenticated u s ->
      has_permission u r ->
      authorized u r
  | auth_delegate : forall u v r,
      manager_of u v ->
      authorized v r ->
      authorized u r.
```

Each inductive is self-contained.
Hallmark compiles them independently, and the generated Prolog
files can be loaded together:

```prolog
% From: authenticated
authenticated(U, S) :-
    valid_credentials(U), fresh_session(S).
authenticated(U, S) :-
    manager_of(U, V), authenticated(V, S).

% From: authorized
authorized(U, R) :- is_admin(U).
authorized(U, R) :-
    authenticated(U, S), has_permission(U, R).
authorized(U, R) :-
    manager_of(U, V), authorized(V, R).
```

The Prolog output is identical, but the Rocq-side organization is
modular: `authenticated` can be proved correct, reused, or replaced
without touching `authorized`.

== Typeclasses as Abstraction Boundaries

Parameterization can be taken further using Rocq's typeclass system.
Instead of hard-coding a dependency on a specific predicate, a rule
set can depend on an _interface_ — a typeclass that any conforming
predicate can implement.

```coq
Class AuthProvider := {
  is_authenticated : user -> session -> Prop;
  auth_decidable : forall u s,
    {is_authenticated u s} + {~ is_authenticated u s};
}.
```

The `authorized` predicate is then parameterized by any
`AuthProvider`:

```coq
Inductive authorized `{AuthProvider} :
    user -> resource -> Prop :=
  | auth_admin : forall u r,
      is_admin u -> authorized u r
  | auth_session : forall u r s,
      is_authenticated u s ->
      has_permission u r ->
      authorized u r
  | auth_delegate : forall u v r,
      manager_of u v ->
      authorized v r ->
      authorized u r.
```

Different systems can supply different `AuthProvider` instances —
password-based, token-based, certificate-based — and the
`authorized` rules remain unchanged.
Each instance ships with a decidability proof, so the properties
proved about `authorized` hold regardless of which provider is
plugged in.

At translation time, Hallmark resolves the typeclass instance,
inlines the concrete `is_authenticated` predicate, and emits Prolog
clauses that reference the corresponding concrete predicate.

== Choosing a Strategy

#figure(
  table(
    columns: 3,
    align: (left, left, left),
    table.header[*Approach*][*When to use*][*Trade-off*],
    [Mutual inductive],
    [Genuine cyclic dependency between predicates],
    [Tight coupling; mutual induction required for proofs],
    [Separate inductives],
    [One-directional dependency; no cycle],
    [Modular; each predicate proved and compiled independently],
    [Typeclass-parameterized],
    [Dependency on an interface; multiple implementations expected],
    [Maximum flexibility; proofs are generic over implementations],
  ),
  caption: [Strategies for composing multi-predicate rule sets.],
) <fig-composition-strategies>

@fig-composition-strategies summarizes the trade-offs.
A well-designed Hallmark project uses all three:
mutual blocks for genuine cycles,
separate inductives for layered dependencies,
and typeclasses for pluggable components.
The generated Prolog is the same flat set of clauses in every case —
the structural choices affect only the Rocq-side organization, the
granularity of proofs, and the ease of future evolution.
