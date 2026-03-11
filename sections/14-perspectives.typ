= Guarantees and Perspectives <sec-perspectives>

== What Hallmark Guarantees

The central claim of Hallmark is _soundness by construction_:
every Prolog clause in the generated program corresponds to a
constructor of a well-typed Rocq inductive definition.

Concretely, this gives three properties:

+ *Soundness of individual rules.*
  Each clause is a faithful rendering of a constructor that has been
  accepted by Rocq's type-checker.
  The premises and conclusion are exactly those specified in the
  inductive definition — no rule is invented, and no rule is omitted.

+ *Consistency of the rule set.*
  Rocq's type theory guarantees that no closed proof of $bot$ can
  be constructed.
  Since the inductive definition lives in this consistent logic,
  the rules cannot derive contradictory conclusions
  (assuming the auxiliary predicates supplied at the Prolog level
  are themselves consistent).

+ *Well-foundedness.*
  Rocq enforces the _strict positivity condition_ on inductive types,
  which prevents self-referential definitions that could lead to
  logical paradoxes.
  This rules out a class of circular rule sets that would cause
  unsound reasoning.

Beyond these structural properties, Rocq allows proving _custom
theorems_ about the inductive definition: convergence of the rules
toward a goal, completeness with respect to a specification, bounded
derivation depth, or monotonicity under fact addition
(see @sec-proofs).
These proofs are established once in Rocq and hold for the generated
Prolog program — they certify behavioral properties that no amount
of testing could cover.

It is important to note what Hallmark does _not_ guarantee by itself.
Prolog's depth-first search may diverge on recursive rule sets, even
when the logical content is well-founded.
Soundness (if the engine answers, the answer is correct) is preserved;
_completeness_ (the engine always terminates with an answer) depends
on the structure of the rules and the Prolog execution strategy.
However, if the user proves termination or bounded depth in Rocq,
that proof constitutes a formal guarantee that divergence cannot occur
for the given rule set.

== Limitations and Scope

Several aspects of Rocq's type system fall outside the current scope
of the translation:

- *Dependent types with computational content.*
  When a constructor's argument involves complex term-level computation
  (e.g. arithmetic expressions in indices), the translation to flat
  Prolog atoms is not always possible.
  Hallmark targets the fragment where indices are variables or
  constructors of simple data types.

- *Universe polymorphism.*
  Rocq's universe hierarchy has no counterpart in Prolog.
  The translation erases universe information, which is sound because
  universes affect type-checking but not the logical content of
  first-order predicates.

- *Higher-order predicates.*
  Horn clauses are first-order.
  Inductive definitions that quantify over predicates (e.g.
  `forall P : nat -> Prop, ...`) cannot be translated into standard
  Prolog.

These restrictions are not arbitrary — they trace the boundary between
the first-order fragment (which Prolog can execute) and the full
dependent type theory (which requires Rocq's own reduction machinery).

== Future Work

- *Verified translation.*
  The Hallmark pipeline runs inside Rocq but the translation function
  itself is not yet proven correct as a formal theorem.
  A natural next step is to state and prove a
  _semantics-preservation_ property: if the translation emits a set
  of clauses $C$ from an inductive type $I$, then every derivation
  in $C$ corresponds to a proof term of type $I$ in Rocq, and vice
  versa.
  MetaRocq provides the infrastructure — the PCUIC representation
  comes with a formalized typing judgment against which the
  translation's output can be related.

- *Translating Definitions and Fixpoints.*
  The current pipeline handles inductive types only.
  Extending it to Rocq `Definition` and `Fixpoint` terms would
  let the translator emit companion Prolog predicates for auxiliary
  computations — list membership, tree traversal, arithmetic guards
  — eliminating the need for hand-written Prolog helpers.
  A `Fixpoint` defined by structural recursion maps naturally to
  one Prolog clause per match branch, with the return value
  becoming an extra relational argument.
  Rocq's termination guarantee carries over, ensuring the generated
  clauses terminate on ground inputs.

== Summary

Hallmark bridges two worlds that have traditionally been separate:
the world of formal proofs, where definitions are verified but not
directly executable as inference engines,
and the world of logic programming, where execution is native but
correctness is on trust.

By recognizing that Rocq inductive types and Prolog clauses are two
notations for the same logical structure — Horn clauses — and by
using MetaRocq to cross between them, Hallmark produces rules engines
that are both provably sound and practically executable.

The resulting architecture is a tower of specializers:
resolution executes clauses,
Prolog interprets them via resolution,
Rocq verifies the definitions that produce them,
and MetaRocq drives the compilation.
Each layer specializes the one above it — and the guarantees
established at the top propagate all the way down to the
executing engine.
