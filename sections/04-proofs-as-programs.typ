= Proofs as Programs <sec-curry-howard>

The previous sections presented logic and Prolog from the perspective
of inference rules and Horn clauses.
We now introduce a different tradition — type theory — and show that
it is, in a precise sense, the _same_ thing viewed from another angle.

== Types as Propositions

In a conventional programming language, types classify values:
`Int` is the type of integers, `Bool` is the type of booleans,
and `Int -> Bool` is the type of functions from integers to booleans.

A surprising observation, discovered independently by Curry and Howard,
is that types can also be read as _logical propositions_:

#figure(
  table(
    columns: 2,
    align: (left, left),
    table.header[*Type theory*][*Logic*],
    [Type $A$],                [Proposition $A$],
    [Term $t : A$],            [Proof of $A$],
    [Function type $A -> B$],  [Implication $A arrow.r.double B$],
    [Pair type $A times B$],   [Conjunction $A and B$],
    [Sum type $A + B$],        [Disjunction $A or B$],
    [Empty type],              [$bot$ (absurdity)],
  ),
  caption: [The Curry-Howard correspondence.],
) <fig-curry-howard>

As summarized in @fig-curry-howard, a function of type $A -> B$ _is_
a proof that $A$ implies $B$: given any proof of $A$ (an input of
type $A$), it produces a proof of $B$ (an output of type $B$).

The analogy is exact.
The formal rules governing type-checking and the formal rules
governing proof-checking are identical.
A type-checker _is_ a proof-checker, and a well-typed program _is_
a valid proof.

== Rocq and the Calculus of Inductive Constructions

Rocq (formerly Coq) is a proof assistant built on this correspondence.
Its underlying logic, the _Calculus of Inductive Constructions_ (CIC),
is a type theory rich enough to express both mathematical theorems and
executable programs.

In Rocq, one writes a theorem by stating its type, then constructs a
term that inhabits that type.
If the term type-checks, the theorem is proved — the machine has
verified the proof.

What makes CIC particularly expressive is _dependent types_: types
that mention values.
For example, one can define the type of lists of length $n$, or the
type of sorted lists, or the type of integers greater than 5.
The type system enforces these constraints statically.

== Inductive Types

The construct most relevant to Hallmark is the _inductive type_.
An inductive type is defined by listing its _constructors_ — the ways
to build values of that type.

Consider the natural numbers:

```coq
Inductive nat : Type :=
  | O : nat
  | S : nat -> nat.
```

This says: $"nat"$ is a type with two constructors.
$"O"$ is a natural number (zero), and $"S"$ takes a natural number and
returns its successor.
Every natural number is either $"O"$ or $"S"(n)$ for some $n$ — there
are no other inhabitants.

Now consider a more interesting example — a predicate expressed as an
inductive type:

```coq
Inductive even : nat -> Prop :=
  | even_O : even O
  | even_SS : forall n, even n -> even (S (S n)).
```

This defines what it means for a natural number to be even:

- $0$ is even (the constructor `even_O` is a proof of `even O`).
- If $n$ is even, then $n + 2$ is even (the constructor `even_SS`
  transforms a proof of `even n` into a proof of `even (S (S n))`).

Read each constructor as an _inference rule_:

$ frac(, "even"(0)) quad quad frac("even"(n), "even"(n + 2)) $

The first is a fact (no premises); the second is a rule with one
premise.
Both are Horn clauses.

The pattern is general.
Every inductive type definition in Rocq is, structurally, a set of
Horn clauses: each constructor is a clause whose conclusion is the type
being defined and whose premises are the constructor's arguments.

Where Rocq differs from Prolog is that it _verifies_ these definitions.
The type-checker ensures that the inductive type is well-founded
(no circular definitions), that the constructors are consistent
(no way to derive a contradiction), and that every use of the type
respects its structure.

Prolog offers no such guarantee — and Hallmark inherits it precisely
by starting from Rocq.
This design echoes the approach taken by CompCert @leroy2006compcert
and CertiCoq @anand2017certicoq, which derive correctness from the
structure of the translation rather than post-hoc testing.
