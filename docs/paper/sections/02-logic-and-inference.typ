= Logic and Inference Rules <sec-logic>

This section recalls the logical notions that both Rocq and Prolog
rely on.
We start from familiar territory — propositional and first-order
logic — and narrow our focus to a specific fragment called
_Horn clauses_, which sits at the heart of the Hallmark pipeline.

== Propositions and Connectives

A _proposition_ is a statement that is either true or false.
Propositions can be combined using logical connectives:
conjunction ($and$), disjunction ($or$), negation ($not$),
and implication ($arrow.r.double$).

An _inference rule_ is a recipe for deriving new propositions from
existing ones.
It is written with premises above a horizontal line and a conclusion
below:

$ frac(A quad A arrow.r.double B, B) $

This rule says: if $A$ holds and $A arrow.r.double B$ holds,
then $B$ holds.
It is known as _modus ponens_ and is one of the most fundamental
rules of deduction.

A _proof_ is a chain of inference rule applications that, starting
from axioms or hypotheses, arrives at the desired conclusion.

== First-Order Logic

Propositional logic is limited to atomic statements and their
combinations.
_First-order logic_ extends it with two powerful tools:

- *Variables and quantifiers.*
  Instead of reasoning about specific objects, we can say
  "for all $x$" ($forall x$) or "there exists $x$" ($exists x$).

- *Predicates.*
  A predicate is a proposition that depends on one or more arguments.
  For instance, $"parent"(x, y)$ asserts that $x$ is a parent of $y$.

An inference rule in first-order logic might look like this:

$ frac(
    "parent"(x, y) quad "parent"(y, z),
    "grandparent"(x, z)
  ) $

Read from bottom to top, this says:
to establish that $x$ is a grandparent of $z$,
it suffices to find some $y$ such that $x$ is a parent of $y$
and $y$ is a parent of $z$.
The variables are implicitly universally quantified.

== Horn Clauses

Not every formula of first-order logic is easy to work with
computationally.
A _Horn clause_ is a restricted form that strikes a balance between
expressiveness and tractability.

A Horn clause is an implication whose conclusion is a single atom and
whose premises are a conjunction of atoms:

$ A_1 and A_2 and dots and A_n arrow.r.double B $

Here, $B$ is called the _head_ and $A_1, dots, A_n$ are the _body_.

There are two important special cases:

- When $n = 0$ (the body is empty), the clause is a _fact_:
  it asserts $B$ unconditionally.
- When $n >= 1$, the clause is a _rule_:
  $B$ holds provided all the $A_i$ hold.

The grandparent rule above is a Horn clause:

$ "parent"(x, y) and "parent"(y, z) arrow.r.double "grandparent"(x, z) $

@fig-horn-anatomy labels the two parts.

#figure(
  table(
    columns: 2,
    align: (center, center),
    table.header[*Part*][*Role*],
    [Body: $A_1 and dots and A_n$],
    [Premises — conditions that must hold],
    [Head: $B$],
    [Conclusion — what the clause establishes],
  ),
  caption: [Anatomy of a Horn clause $A_1 and dots and A_n arrow.r.double B$.],
) <fig-horn-anatomy>

Horn clauses are important because they are the largest fragment of
first-order logic for which efficient, complete proof search
procedures exist @kowalski1974predicate.
Both Prolog and Rocq's inductive definitions can be understood in
terms of Horn clauses — a fact that Hallmark exploits directly.

== From Rules to Systems

A collection of Horn clauses defines a _logical theory_:
a set of facts and rules that together characterize what can be derived.
Given a theory and a _goal_ (a proposition to prove), the task of
a rules engine is to determine whether the goal follows from the
theory — and if so, to produce the derivation.

The next section addresses precisely that problem:
how Prolog turns a set of Horn clauses into a working inference engine.
