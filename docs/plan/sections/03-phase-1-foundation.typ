= Phase 1 — Foundation <sec-phase-1>

This phase establishes the project skeleton: opam switch, dune build, file layout, and the first successful MetaRocq quoting of an inductive definition.

== Step 1.1 — Project scaffold <sec-step-1-1>

Create the dune-based project structure:

- `dune-project` with `(lang dune 3.21)` and `(using rocq 0.11)`.
- `theories/dune` with a `(rocq.theory (name Hallmark) (theories Stdlib MetaRocq.Template))` stanza and `(include_subdirs qualified)`.
- `examples/dune` with `(rocq.theory (name HallmarkExamples) (theories Stdlib Hallmark))`.
- `test/dune` with `(rocq.theory (name HallmarkTest) (theories Stdlib Hallmark HallmarkExamples))`.
- `hallmark.switch` pinning `rocq-core`, `rocq-stdlib`, `coq-metacoq-template`, `dune`.
- `scripts/setup.sh` that creates the opam switch and imports the switch file.

*Code deliverable:* `dune build` succeeds on an empty `theories/Hallmark.v` that imports `MetaCoq.Template.All`.

*Test deliverable (L1):* `test/TestImport.v` containing:
```
From MetaCoq.Template Require Import All.
From Hallmark Require Import Hallmark.
Example smoke : 1 = 1 := eq_refl.
```
`dune build @runtest` compiles this file.

== Step 1.2 — Define the running example <sec-step-1-2>

Write the `allowed` inductive in `examples/Allowed.v`.
Include auxiliary types (`user`, `resource`) and base predicates (`manager_of`, `public`, `revoked`) as inductives or parameters.

*Code deliverable:* `examples/Allowed.v` compiles via `dune build`.

*Test deliverable (L1):* `test/TestAllowedDef.v` with:
```
From HallmarkExamples Require Import Allowed.
Example admin_access : allowed admin secret_report := admin_all _.
```
The example constructs a proof term directly — compilation proves the inductive is well-formed.

== Step 1.3 — Quote the inductive with MetaRocq <sec-step-1-3>

Use `tmQuoteRec "allowed"` inside a `MetaCoq Run` block to obtain the `program` (global environment + entry point).
Store the result in a Rocq definition via `tmDefinition`.

*Code deliverable:* `examples/QuoteAllowed.v` compiles and defines `allowed_program : program`.

*Test deliverable (L1):* `test/TestQuote.v` with:
```
From HallmarkExamples Require Import QuoteAllowed.
Example quoted_is_some :
  lookup_env allowed_program (kn_of "allowed") <> None.
```

== Step 1.4 — Extract the `mutual_inductive_body` <sec-step-1-4>

Write `theories/Lookup.v` with a function `find_inductive : program -> kername -> option mutual_inductive_body` that looks up the target inductive in the quoted global environment by matching on `InductiveDecl` entries.

*Code deliverable:* `theories/Lookup.v` compiles.

*Test deliverable (L1):* `test/TestLookup.v` with:
```
From Hallmark Require Import Lookup.
From HallmarkExamples Require Import QuoteAllowed.

Example found_allowed :
  match find_inductive allowed_program (kn_of "allowed") with
  | Some mib => length (ind_bodies mib) =? 1
  | None => false
  end = true
:= eq_refl.
```

== Step 1.5 — Inspect constructor types <sec-step-1-5>

Write `theories/Inspect.v` with `get_constructors : mutual_inductive_body -> list (ident * term)` that extracts each constructor's name and raw type from `ind_ctors`.

*Code deliverable:* `theories/Inspect.v` compiles.

*Test deliverable (L1):* `test/TestInspect.v` asserting the three constructor names are present:
```
From Hallmark Require Import Lookup Inspect.
From HallmarkExamples Require Import QuoteAllowed.

Example three_constructors :
  match find_inductive allowed_program (kn_of "allowed") with
  | Some mib => length (get_constructors mib) =? 3
  | None => false
  end = true
:= eq_refl.
```
