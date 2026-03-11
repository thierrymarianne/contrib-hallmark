# Rocq Typeclass System

## Overview

Typeclasses in Rocq are a mechanism for ad-hoc polymorphism inspired by Haskell's typeclasses, but built on top of the existing record and instance resolution infrastructure.
A typeclass is a record type; an instance is a term of that record type; and instance resolution is performed by a specialized proof search engine integrated into the elaborator.

## Defining a Typeclass

A typeclass is declared with the `Class` keyword.
Under the hood, it is a dependent record.

```coq
Class Eq (A : Type) := {
  eqb : A -> A -> bool;
  eqb_refl : forall x, eqb x x = true;
}.
```

This defines:
- A record type `Eq` parameterized by `A`.
- A field `eqb` (the decidable equality function).
- A field `eqb_refl` (a proof obligation that every instance must fulfill).

Methods can be both computational (functions) and logical (proofs), blending the Haskell notion of typeclass with Rocq's ability to enforce invariants.

## Declaring Instances

Instances are registered with the `Instance` keyword (or `#[export] Instance` for controlled visibility).

```coq
Instance Eq_nat : Eq nat := {
  eqb := Nat.eqb;
  eqb_refl := Nat.eqb_refl;
}.
```

Instances can depend on other instances (like Haskell's instance contexts):

```coq
Instance Eq_pair (A B : Type) `{Eq A} `{Eq B} : Eq (A * B) := {
  eqb p1 p2 := eqb (fst p1) (fst p2) && eqb (snd p1) (snd p2);
  eqb_refl := ...;
}.
```

The backquote syntax `` `{Eq A} `` is an _implicit generalization_: it adds a constraint that an `Eq A` instance must be available, without naming it explicitly.

## Instance Resolution

When a function or lemma uses a typeclass method, Rocq must find the appropriate instance.
This is done by a proof search procedure:

1. The elaborator encounters a goal of the form `Eq ?A` (a typeclass constraint to satisfy).
2. It searches the instance database — a set of hints registered by `Instance` declarations.
3. It tries to unify each candidate with the goal, recursively resolving sub-constraints.
4. If exactly one instance matches, it is inserted automatically. If none match or resolution is ambiguous, an error is raised.

The search uses **eauto-style** backward chaining with a bounded depth (default: 100 steps).
It is essentially a Prolog-like proof search over the instance database.

## Implicit Arguments and the Backquote

The backquote syntax has several forms:

- `` `{Eq A} `` — anonymous constraint, implicit.
- `` `{H : Eq A} `` — named constraint (useful when the instance must be referenced in the body).
- `` `{! Eq A} `` — strict, no implicit generalization of `A` (it must already be in scope).

Typeclass arguments are passed implicitly: the user writes `eqb x y` and the elaborator fills in the `Eq` dictionary behind the scenes.

## Operational Typeclasses

Typeclasses are commonly used for:

### Decidable Equality
```coq
Class DecEq (A : Type) := { dec_eq : forall x y : A, {x = y} + {x <> y} }.
```

### Ordering
```coq
Class Ord (A : Type) `{Eq A} := {
  compare : A -> A -> comparison;
  compare_spec : forall x y, CompareSpec (x = y) (lt x y) (lt y x) (compare x y);
}.
```

### Monoid, Functor, Monad
Algebraic structures and computational patterns are naturally expressed as typeclasses:
```coq
Class Monoid (A : Type) := {
  mempty : A;
  mappend : A -> A -> A;
  mappend_assoc : forall x y z, mappend x (mappend y z) = mappend (mappend x y) z;
  mempty_left : forall x, mappend mempty x = x;
  mempty_right : forall x, mappend x mempty = x;
}.
```

## Typeclasses vs Canonical Structures

Rocq offers two overlapping mechanisms for ad-hoc polymorphism:

| Feature             | Typeclasses                    | Canonical Structures         |
|---------------------|--------------------------------|------------------------------|
| Resolution trigger  | Unresolved implicit argument   | Unification failure          |
| Search strategy     | Proof search (eauto-like)      | Unification hints            |
| Backtracking        | Yes                            | Limited                      |
| Typical use         | Algebraic abstractions, deriving | MathComp-style hierarchies |

Typeclasses are more flexible (backtracking search) but can be slower on large hierarchies.
Canonical structures are more predictable but harder to compose.

## Hierarchy Building

Typeclasses support subclassing through dependent instance constraints:

```coq
Class Semigroup (A : Type) := { sg_op : A -> A -> A }.
Class Monoid (A : Type) `{Semigroup A} := { mon_unit : A }.
Class Group (A : Type) `{Monoid A} := { inv : A -> A }.
```

Each layer adds structure on top of the previous one.
An instance of `Group` automatically provides `Monoid` and `Semigroup` through the chain of constraints.

## Connection to Proof Search

The instance resolution mechanism is deeply relevant to Hallmark:
- It is a backward-chaining search, much like Prolog's SLD resolution.
- The instance database plays the role of a clause database.
- Each `Instance` declaration is essentially a Horn clause: its constraints are premises, its conclusion is the typeclass it provides.
- Resolution can diverge if instances form cycles (just like Prolog).

This means typeclasses themselves are a form of logic programming embedded in Rocq — an alternative angle on the same Horn-clause correspondence that Hallmark exploits for inductive types.

## Controlling Resolution

- `Hint Mode` directives constrain which arguments must be ground before resolution fires (prevents divergence on underspecified goals).
- `Typeclasses Opaque` / `Typeclasses Transparent` control which definitions are unfolded during search.
- `Set Typeclasses Depth N` limits the search depth.
- `Existing Instance` registers a previously defined term as an instance without re-declaring it.
- `#[local]`, `#[export]`, `#[global]` control visibility across modules.
