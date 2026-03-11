#pagebreak()

= Constraint Logic Programming Extensions <sec-clp>

The Hallmark pipeline presented so far translates inductive constructors
into pure Prolog clauses — facts and rules built from atoms and
unification.
This covers a wide range of rule systems, but many real-world
specifications involve _constraints_: arithmetic inequalities,
boolean combinations, or linear bounds that go beyond simple
pattern matching.

SWI-Prolog provides a family of Constraint Logic Programming (CLP)
libraries that extend the basic search with domain-specific solvers.
Rather than enumerating values, these libraries let the engine post
constraints on variables and propagate them, pruning the search space
before any backtracking occurs.

The challenge is to connect Rocq propositions — which express
constraints through their type structure — to the appropriate CLP
syntax on the Prolog side.
Hallmark solves this with a _typeclass-driven_ bridge: the translator
looks up typeclass instances to decide how a given Rocq premise should
be emitted.

== The Emittable Typeclass

At the core of the bridge is a typeclass that marks a Rocq proposition
as translatable to a specific Prolog construct:

```coq
Class Emittable (P : Prop) := {
  emit : string;
}.
```

Every Rocq proposition that carries an `Emittable` instance is
recognized by the translator during constructor analysis.
Instead of emitting a plain Prolog atom, the translator inserts the
string provided by `emit` — which can be a CLP constraint expression,
a built-in predicate, or any valid Prolog goal.

For standard propositions (applications of inductive predicates),
Hallmark generates the instance automatically.
For constraint-bearing propositions, the user provides instances that
target the appropriate CLP library.

== CLP(FD) — Integer Constraints

Many rule systems involve conditions on integer quantities: ages,
thresholds, counts, priorities.
In Rocq, these appear as propositions over `nat` or `Z` using
comparisons like `le`, `lt`, or `Nat.leb`.

The user provides `Emittable` instances that map these to CLP(FD)
constraints:

```coq
Instance emit_le (n m : nat) : Emittable (n <= m) := {
  emit := emit_var n ++ " #=< " ++ emit_var m;
}.

Instance emit_lt (n m : nat) : Emittable (n < m) := {
  emit := emit_var n ++ " #< " ++ emit_var m;
}.

Instance emit_range (n lo hi : nat) :
    Emittable (lo <= n /\ n <= hi) := {
  emit := emit_var n ++ " in " ++ show lo ++ ".." ++ show hi;
}.
```

With these instances registered, an inductive definition like:

```coq
Inductive eligible : person -> nat -> Prop :=
  | senior : forall p age,
      age_of p age -> 65 <= age -> eligible p age
  | minor  : forall p age,
      age_of p age -> age < 18 -> eligible p age.
```

generates Prolog with CLP(FD) constraints rather than unresolvable
atoms:

```prolog
:- use_module(library(clpfd)).

eligible(P, Age) :- age_of(P, Age), Age #>= 65.
eligible(P, Age) :- age_of(P, Age), Age #< 18.
```

The solver handles domain propagation: if `Age` is constrained
elsewhere, these bounds interact automatically with the rest of the
search.

== CLP(B) — Boolean Constraints

Policy engines often involve boolean combinations: feature flags,
permission bits, mutually exclusive options.
CLP(B) expresses these as satisfiability constraints over `{0, 1}`
variables.

```coq
Instance emit_bool_and (a b : bool) :
    Emittable (a = true /\ b = true) := {
  emit := "sat(" ++ emit_var a ++ " * " ++ emit_var b ++ ")";
}.

Instance emit_bool_or (a b : bool) :
    Emittable (a = true \/ b = true) := {
  emit := "sat(" ++ emit_var a ++ " + " ++ emit_var b ++ ")";
}.

Instance emit_bool_implies (a b : bool) :
    Emittable (a = true -> b = true) := {
  emit := "sat(" ++ emit_var a ++ " =< " ++ emit_var b ++ ")";
}.
```

An access-control policy with feature gates:

```coq
Inductive feature_access : user -> feature -> Prop :=
  | beta_tester : forall u f,
      beta_flag u f ->
      feature_access u f
  | premium_or_trial : forall u f p t,
      premium_flag u p -> trial_flag u t ->
      (p = true \/ t = true) ->
      feature_access u f.
```

translates to:

```prolog
:- use_module(library(clpb)).

feature_access(U, F) :- beta_flag(U, F).
feature_access(U, F) :-
    premium_flag(U, P), trial_flag(U, T),
    sat(P + T).
```

The CLP(B) solver determines satisfiability without enumerating all
combinations of `P` and `T`.

== CLP(Q/R) — Linear Arithmetic

Budget allocation, resource planning, and financial rules involve
linear constraints over rational or real-valued quantities.
CLP(Q) handles these with exact rational arithmetic; CLP(R) uses
floating-point for performance.

```coq
Instance emit_q_leq (x y : Q) : Emittable (Qle x y) := {
  emit := "{ " ++ emit_var x ++ " =< " ++ emit_var y ++ " }";
}.

Instance emit_q_sum (x y z : Q) :
    Emittable (x + y == z)%Q := {
  emit := "{ " ++ emit_var x ++ " + "
               ++ emit_var y ++ " = "
               ++ emit_var z ++ " }";
}.
```

A budget allocation rule:

```coq
Inductive within_budget :
    department -> Q -> Q -> Prop :=
  | budget_ok : forall d spent limit,
      budget_limit d limit ->
      (spent <= limit)%Q ->
      within_budget d spent limit.
```

generates:

```prolog
:- use_module(library(clpq)).

within_budget(D, Spent, Limit) :-
    budget_limit(D, Limit),
    { Spent =< Limit }.
```

The Simplex-based solver in CLP(Q) handles the inequality natively,
without the need to ground `Spent` or `Limit` before the check.

== How the Translator Uses Instances

During the translation stage (@sec-hallmark), when the translator
encounters a constructor argument whose type is a proposition $P$,
it proceeds as follows:

+ *Instance lookup.*
  The translator queries the typeclass database for an instance
  of `Emittable P`.
  Because instance resolution in Rocq is itself backward chaining
  over the instance database, this lookup is automatic and
  compositional — compound constraints are resolved through the
  chain of instances.

+ *If an instance is found:* the translator calls `emit` to obtain
  the Prolog syntax and inserts it directly into the clause body.
  The appropriate `:- use_module` directive is added to the file
  header.

+ *If no instance is found:* the translator falls back to the
  default behavior — treating $P$ as an application of an inductive
  predicate and emitting a plain Prolog atom.

This design is _open_: users can register new `Emittable` instances
for custom propositions without modifying the translator itself.
A library of standard instances for common CLP domains ships with
Hallmark, covering arithmetic comparisons, boolean connectives, and
linear constraints.

== Preserving Guarantees

The CLP extension does not weaken Hallmark's soundness properties.
Each `Emittable` instance maps a Rocq proposition to a Prolog
constraint that preserves its logical meaning:

- The Rocq side still type-checks the inductive definition, including
  the constraint-carrying premises.
  All the properties proved about the rules (@sec-proofs) remain valid.

- The Prolog side replaces what would be an unresolvable atom with a
  CLP call that computes the same truth value — but more efficiently,
  using the constraint solver instead of enumeration.

The key invariant is that the `emit` function must produce Prolog code
whose satisfiability coincides with the truth of the Rocq proposition.
This is a _semantic correctness_ obligation on the instance author.
In the current design it is informal; a future direction is to state
it as a formal theorem within Rocq, proving that each `Emittable`
instance is faithful.
