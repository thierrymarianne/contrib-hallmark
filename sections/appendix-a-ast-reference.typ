#pagebreak()

#counter(heading).update(0)
#set heading(numbering: "A.1", supplement: [Appendix])

= MetaRocq AST Reference <appendix-ast>

This appendix lists the MetaRocq term constructors that Hallmark
encounters during compilation, grouped by the role they play in the
pipeline.
For each constructor, we give its MetaRocq signature, its meaning, and
the Hallmark function responsible for compiling it.

== Global Entry Points

The translator begins with global declarations obtained via
`tmQuoteRec`.
Two forms are relevant:

- *`InductiveDecl`* (`kername -> mutual_inductive_body`).
  A mutual block of inductive types.
  Contains `ind_bodies` (list of `one_inductive_body`),
  `ind_npars` (parameter count), and a universe context.
  Handled by `compile_mutual_inductive`, which iterates over
  `ind_bodies` and calls `compile_one_inductive` for each entry.

- *`ConstantDecl`* (`kername -> constant_body`).
  A global definition or axiom.
  `cst_body = Some t` for definitions, `None` for axioms.
  Not compiled in the current pipeline.
  Future work: `compile_constant` for `Definition` / `Fixpoint`
  support.

Each `one_inductive_body` contains:

- `ind_name : ident` — the predicate name.
- `ind_type : term` — the full type (e.g. `user -> resource -> Prop`).
- `ind_ctors : list (ident * term * nat)` — one entry per constructor: name, type, arity.

The function `compile_one_inductive` iterates over `ind_ctors` and
calls `compile_constructor` on each entry.

== Constructor Type Traversal

A constructor's type is a nested chain of `tProd` bindings ending in
an application of the inductive being defined.
`compile_constructor` walks this chain, classifying each binding.
The following term constructors are encountered during this walk:

- *`tProd`* (`name -> term -> term`).
  Dependent product `forall (x : A), B` — the backbone of constructor
  types.
  Handled by `classify_binding`: inspect the type `A` to decide
  if this is an index variable, a premise, or an erased argument,
  then recurse into `B`.

- *`tApp`* (`term -> list term`).
  Application `f args`.
  At the end of the chain, `tApp (tInd ...) args` is the conclusion
  of the clause.
  Handled by `extract_head_predicate`: collect the predicate name and
  its index arguments to form the clause head.

- *`tInd`* (`inductive -> universe_instance`).
  Reference to an inductive type.
  Appears inside `tApp` as the head of a predicate application.
  Handled by `resolve_predicate`: look up the inductive name, check
  if it belongs to the current mutual block or is external.

- *`tConstruct`* (`inductive -> nat -> universe_instance`).
  Reference to a data constructor (e.g. `S`, `nil`, `cons`).
  Appears in index positions.
  Handled by `emit_constructor_term`: translate to a Prolog functor
  (e.g. `s(N)`, `[]`, `[H|T]`).

- *`tRel`* (`nat`).
  De Bruijn variable reference.
  Refers to a binding introduced by an enclosing `tProd` or `tLambda`.
  Handled by `resolve_variable`: map the de Bruijn index to a named
  Prolog variable using the binding context built during the `tProd`
  walk.

- *`tConst`* (`kername -> universe_instance`).
  Reference to a global constant (`Definition`, `Lemma`, `Axiom`).
  Handled by `resolve_constant`: if an `Emittable` instance exists,
  call `emit`; otherwise emit as a plain Prolog atom referencing the
  constant name.

- *`tSort`* (`universe`).
  Sort: `Prop`, `Set`, or `Type u`.
  Appears as the target sort of the inductive type.
  Erased — sorts carry no computational content for clause generation.

== Binding Classification

When `compile_constructor` encounters a `tProd na A B`, it inspects
`A` (the type of the binding) to decide its role:

- *Recursive premise.*
  `A` has the shape `tApp (tInd ind _) args` where `ind` belongs to
  the current mutual block.
  Emitted as a body atom: a call to a co-defined predicate.

- *External premise.*
  `A` has the shape `tApp (tInd ind _) args` where `ind` is not in
  the current block.
  Emitted as a body atom: a call to an auxiliary predicate.

- *Index variable.*
  `A` is a `tSort _` or a plain `tInd _ _` (a data type).
  The bound variable appears in the head and/or body as a Prolog
  variable.

- *Constraint premise.*
  `A` is any proposition for which an `Emittable A` instance exists.
  Emitted as a body constraint via the `Emittable.emit` method
  (CLP syntax).

- *Erased.*
  `A` involves type-level computation, universe constraints, or
  proof-irrelevant content.
  Dropped from the clause.

== Structures Not Currently Handled

The following term constructors appear in Rocq's AST but are outside
the scope of the current Hallmark translation:

- *`tLambda`* (`name -> term -> term`).
  Lambda abstractions do not appear at the top level of constructor
  types.
  They arise inside `tFix` bodies (future work).

- *`tLetIn`* (`name -> term -> term -> term`).
  Local let bindings.
  Could be inlined during translation.
  Not currently handled.

- *`tCase`* (`(inductive * nat) -> term -> term -> list (nat * term)`).
  Pattern matching.
  Appears in `Fixpoint` bodies.
  Required for `Fixpoint` compilation (future work).

- *`tFix`* (`mfixpoint term -> nat`).
  Fixpoint definitions.
  Each entry contains `dtype`, `dbody`, and `rarg` (decreasing
  argument index).
  Future work: one clause per match branch in `dbody`.

- *`tCoFix`* (`mfixpoint term -> nat`).
  Cofixpoints (co-recursive definitions).
  No clear Prolog counterpart.
  Out of scope.

- *`tProj`* (`projection -> term`).
  Record projection.
  Could be translated to Prolog `arg/N` accessors.
  Not currently handled.

- *`tCast`* (`term -> cast_kind -> term`).
  Type cast.
  Absent from the PCUIC representation.
  Erased.

- *`tVar`* (`ident`).
  Named variable (sections).
  Resolved before quoting.

- *`tEvar`* (`nat -> list term`).
  Existential variable (hole).
  Should not appear in complete definitions.
