= From Types to Clauses <sec-bridge>

The previous two sections developed two parallel tracks:
Prolog, which executes Horn clauses by backward chaining,
and Rocq, whose inductive types are structurally sets of Horn clauses
verified by the type-checker.
We now make the connection explicit and introduce the tool that enables
it: MetaRocq.

== The Structural Correspondence

Let us place a Rocq inductive definition side by side with its
Prolog equivalent.

On the Rocq side, consider a simple access-control policy:

```coq
Inductive allowed : user -> resource -> Prop :=
  | admin_all  : forall r, allowed admin r
  | read_public : forall u, allowed u public_doc
  | delegate   : forall u v r,
      manager_of u v -> allowed v r -> allowed u r.
```

Each constructor is a clause:

- `admin_all`: the administrator may access any resource.
  No premises — this is a fact.
- `read_public`: any user may access the public document.
  Again a fact.
- `delegate`: if $u$ manages $v$ and $v$ has access to $r$,
  then $u$ also has access to $r$.
  This is a rule with two premises.

The corresponding Prolog program writes itself:

```prolog
allowed(admin, R).
allowed(U, public_doc).
allowed(U, R) :- manager_of(U, V), allowed(V, R).
```

The translation is mechanical:
the constructor name disappears (it was a proof label, not
computational content),
each universally quantified variable becomes a Prolog variable,
the recursive and non-recursive premises become body atoms,
and the conclusion becomes the head.

The correspondence is structural: both sides are notations for the
same logical object, a Horn clause.

== What Rocq Brings to the Table

The Prolog version is shorter and immediately executable.
What does the Rocq detour buy us?

The answer is _static guarantees_ enforced by the type-checker:

- *Well-foundedness.* Rocq checks that the inductive definition does
  not contain vicious circles. An inductively-defined predicate cannot
  assume itself in its own definition without going through a
  structurally smaller argument.
  In Prolog, a circular clause like `p(X) :- p(X)` is legal but causes
  non-termination.

- *Consistency.* The Calculus of Inductive Constructions guarantees
  that no closed term of type $bot$ (falsehood) can be constructed.
  This means the rules cannot derive a contradiction.

- *Type correctness.* Every argument to a constructor is type-checked.
  If the policy mentions `user` and `resource` as distinct types, the
  type-checker prevents mixing them up — a class of errors that Prolog's
  untyped terms cannot catch.

These guarantees come for free from the type-checker.
But Rocq offers something far more powerful: the ability to prove
_arbitrary theorems_ about the inductive definition, using the full
strength of the Calculus of Inductive Constructions.
The next section is devoted entirely to this capability.

== MetaRocq: Inspecting Definitions from Within

The remaining question is practical: how do we get from the Rocq
definition to the Prolog text?

One approach would be to write an external tool that parses Rocq source
files and emits Prolog.
But this would be fragile, tied to Rocq's surface syntax, and itself
unverified.

MetaRocq @sozeau2020metacoq offers a better path.
It is a framework, written in Rocq, that provides a _term-level
representation_ of Rocq's own internal syntax.
Using MetaRocq, a Rocq program can _quote_ any definition — including
inductive types — into a data structure that can be inspected, pattern-
matched, and transformed like any other Rocq value.

The key mechanism is the _TemplateMonad_, an effectful monad that
interacts with the Rocq environment:

- `tmQuoteRec`: recursively quotes a term and all its dependencies
  into the Template-Rocq AST.
- `tmMkDefinition`: splices a constructed AST back into the
  environment.

For Hallmark, we use the first half: we quote an inductive definition,
walk its list of constructors, and for each constructor extract:

+ The _name_ (used only for traceability).
+ The _argument types_ (which become premises / body atoms).
+ The _return type_ (which becomes the conclusion / head atom).

This information is everything we need to emit a Prolog clause.

== The Translation in Outline

Given a quoted inductive type with constructors $c_1, dots, c_k$,
the translation proceeds as follows for each constructor $c_i$:

+ *Parse the type* of $c_i$ as a chain of dependent products
  (the CIC equivalent of $forall$).
  Each product binding introduces either a _data argument_ (a
  variable that will appear in the clause) or a _proof argument_
  (a recursive or auxiliary premise).

+ *Separate premises from conclusion.*
  Proof arguments whose type is an application of a known inductive
  predicate become body atoms.
  The final return type becomes the head atom.

+ *Emit the Prolog clause.*
  The head is the predicate applied to its data arguments.
  The body is the conjunction of the atoms from step 2.
  Variables are mapped to Prolog variables.

The result is a set of Prolog clauses that is logically equivalent to
the original inductive definition — one clause per constructor,
faithful in structure.
