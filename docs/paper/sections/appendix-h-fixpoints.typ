#pagebreak()

= Translating Fixpoints <appendix-fixpoints>

The main pipeline described in @sec-hallmark translates inductive
type definitions.
Rocq also supports _structural recursion_ through `Fixpoint`
definitions, and many natural rule sets are expressed this way —
reachability, path existence, chain membership.
Hallmark extends its translation to cover a restricted but useful
fragment of `Fixpoint`.

== Supported Fragment

The supported fragment is a single, non-mutual `Fixpoint` whose
body is a sequence of lambda binders followed by exactly one `match`
expression:

```coq
Fixpoint f (a1 : T1) ... (an : Tn) : Prop :=
  match ai with
  | C1 p1 ... => body1
  | C2 p1 ... => body2
  | ...
  end.
```

Nested matches, multi-fixpoint blocks (`with` syntax), and fixpoints
returning non-`Prop` types are outside the supported fragment and are
silently ignored by the pipeline.

== Strategy

The translation reuses the entire inductive classification machinery.
The key obstacle is the self-reference: inside the fixpoint body, a
recursive call refers to `f` itself via a de Bruijn index, which is
not the shape that `classify_binding` expects for a recursive premise.

`analyze_fixpoint` in `TranslateFixpoint.v` eliminates this
obstacle before any classification takes place:

```
subst0 [tInd (mkInd kn 0) []] (dbody def)
```

This substitution replaces the self-reference with a synthetic
`tInd` carrying the fixpoint's own kername.
After substitution, recursive calls have exactly the shape
`tInd fix_kn args` — identical to the inductive applications that
`classify_binding` already recognises as `BRecursive`.
The rest of the translation can then proceed without knowing it is
handling a fixpoint rather than an inductive.

== One Clause per Branch

Each constructor branch of the `match` becomes one Prolog clause.
Clauses are named `fixname_ctorname` (e.g. `reachable_here`,
`reachable_step`).

=== Head

The clause head is built by `build_fix_head`.
Lambda arguments that are _not_ the matched argument become plain
`PVar j` positions.
The matched argument position is replaced by a constructor pattern
`PApp ctor_name [pattern_vars]` where the pattern variables come
from the branch's `bcontext` (the variables bound by pattern
matching on the constructor).

=== Body

Inside a branch, `parse_telescope` unwraps any additional `forall`
(or `->`) binders in the branch body, and `classify_all` labels
each binding as `BIndex`, `BExternal`, `BRecursive`, or `BErased`
exactly as in the inductive case.
`extract_body_at` then emits body atoms, starting its de Bruijn
depth counter at `offset = nargs + bctx_len` to account for the
lambda and pattern-variable binders already in scope.

The return type of the branch (what remains after stripping all
binders) is classified separately:

- `True` or a universe sort: no extra body goal.
  The clause body comes entirely from the telescope premises.
- `False`: the branch is _skipped_.
  A `False`-typed branch is unreachable by construction and
  produces no Prolog clause.
- Any other predicate application: appended as an extra body goal
  after the telescope premises.
  This is the common case for fixpoints that delegate to another
  predicate in their base case.

=== Example

```coq
Inductive chain := here : person -> chain
                 | step : person -> chain -> chain.

Fixpoint reachable (start : person) (c : chain) : Prop :=
  match c with
  | here dest     => knows start dest
  | step mid rest => knows start mid -> reachable mid rest
  end.
```

For the `here` branch:
- Head: `reachable(Start, here(Dest))` — `Start` from lambda arg 0,
  `here(Dest)` from the matched position with pattern variable `Dest`.
- The branch body `knows start dest` strips to zero telescope
  binders; its return type is `knows(Start, Dest)`, appended as
  an extra goal.
- Emitted clause:

```prolog
reachable(Start, here(Dest)) :-
    rule(reachable_here), knows(Start, Dest).
```

For the `step` branch:
- Head: `reachable(Start, step(Mid, Rest))`.
- The branch body `knows start mid -> reachable mid rest` yields
  one telescope binder `(_ : knows start mid)` classified as
  `BExternal`, plus a return type of `reachable(Mid, Rest)` appended
  as an extra goal.
- Emitted clause:

```prolog
reachable(Start, step(Mid, Rest)) :-
    rule(reachable_step), knows(Start, Mid), reachable(Mid, Rest).
```

== Proof Witnesses for Fixpoints

Fixpoint clauses use `fix_witness/4` instead of `ctor_witness/4`:

```prolog
fix_witness(Name, Head, [Body...], NPremises).
```

`NPremises` counts the telescope premises — the body goals produced
by `extract_body_at` — _excluding_ the extra return-type goal.
The extra goal, if present, is the recursive conclusion and is
handled differently during reconstruction.

For the `reachable` example:

```prolog
fix_witness(reachable_here,
    reachable(Start, here(Dest)),
    [knows(Start, Dest)], 0).
fix_witness(reachable_step,
    reachable(Start, step(Mid, Rest)),
    [knows(Start, Mid), reachable(Mid, Rest)], 1).
```

For `reachable_here`, `NPremises = 0`: there are no telescope
premises, and the single body goal `knows(Start, Dest)` is the
return-type conclusion.
In Rocq, this corresponds to applying the `knows` proof directly.

For `reachable_step`, `NPremises = 1`: the first body goal
`knows(Start, Mid)` is a telescope premise (a function argument
in the Rocq proof term), and `reachable(Mid, Rest)` is the
recursive conclusion.

During reconstruction, `wrap_funs` wraps the first `NPremises`
subproofs as `fun _ : T => ...` binders around the recursively
reconstructed conclusion witness.
The Rocq term for a resolved `reachable(start, step(mid, rest))`
query takes the form:

```coq
fun _ : knows start mid => reachable_proof
```

where `reachable_proof` is the witness reconstructed from the
subproof of `reachable(mid, rest)`.
