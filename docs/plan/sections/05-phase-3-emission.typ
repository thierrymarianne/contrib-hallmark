= Phase 3 — Prolog Emission and CLI Binary <sec-phase-3>

This phase converts the internal clause IR into Prolog source text, extracts the translation to OCaml, and builds the `hallmark` CLI binary.
The end result is a standalone executable: `.v` file in, `.pl` file out.

Tests are split across Layer 1 (Rocq string equality), Layer 2 (Prolog `plunit`), and binary integration tests.

== Step 3.1 — Pretty-print `prolog_term` <sec-step-3-1>

Write `theories/Emit.v` with `print_term : prolog_term -> string`:
- Variables are capitalized (`X0`, `X1`, ...).
- Atoms are lowercase.
- Compound terms use `f(a, b, c)` notation.
- Zero-arity atoms print without parentheses.

*Code deliverable:* `theories/Emit.v` compiles (partial — term printing only).

*Test deliverable (L1):* `test/TestEmit.v`:
```
Example print_compound :
  print_term (PApp "allowed" [PAtom "admin", PVar 0])
  = "allowed(admin, X0)"
:= eq_refl.

Example print_atom :
  print_term (PAtom "admin") = "admin"
:= eq_refl.

Example print_var :
  print_term (PVar 3) = "X3"
:= eq_refl.
```

== Step 3.2 — Pretty-print a clause <sec-step-3-2>

Add `print_clause : clause -> string` to `theories/Emit.v`:
- Facts: `head.`
- Rules: `head :- rule(name), body1, ..., bodyN.`
- First body atom is always `rule(constructor_name)` for traceability.

*Code deliverable:* `theories/Emit.v` extended.

*Test deliverable (L1):* `test/TestEmit.v`:
```
Example print_delegate_clause :
  print_clause delegate_clause =
  "allowed(X0, X2) :- rule(delegate), manager_of(X0, X1), allowed(X1, X2)."
:= eq_refl.

Example print_admin_fact :
  print_clause admin_all_clause =
  "allowed(admin, X0) :- rule(admin_all)."
:= eq_refl.
```

== Step 3.3 — Emit the `rule/1` fact <sec-step-3-3>

Add the universal `rule(_).` header to program output.
This ensures `rule(Name)` always succeeds at zero cost.

*Code deliverable:* `theories/Emit.v` extended.

*Test deliverable (L1):* `test/TestEmit.v`:
```
Example program_starts_with_rule :
  is_prefix "rule(_)." (print_program [admin_all_clause]) = true
:= eq_refl.
```

== Step 3.4 — Assemble a full program <sec-step-3-4>

Write `print_program : list clause -> string` that concatenates a header comment, the `rule(_).` fact, and all clauses separated by newlines.

*Code deliverable:* `theories/Emit.v` feature-complete for text generation.

*Test deliverable (L1):* `test/TestEmit.v` — assert the full program for `allowed` contains all three clause heads:
```
Example program_contains_all_clauses :
  let prog := print_program (translate_inductive allowed_mib) in
  (is_substring "admin_all" prog) &&
  (is_substring "read_public" prog) &&
  (is_substring "delegate" prog) = true
:= eq_refl.
```

== Step 3.5 — `TemplateMonad` pipeline <sec-step-3-5>

Write `theories/Pipeline.v` with the full pipeline function that ties quoting, translation, and emission together:

```
Definition hallmark_pipeline (name : string) : TemplateMonad string :=
  prog <- tmQuoteRec name ;;
  let kn := kn_of name in
  match find_inductive prog kn with
  | Some mib =>
    let clauses := translate_inductive mib in
    let prolog := print_program clauses in
    tmMsg prolog ;;
    tmReturn prolog
  | None => tmFail ("Inductive not found: " ++ name)
  end.
```

The function uses `tmMsg` to print the Prolog text to Rocq's feedback channel.
This is the Gallina entry point — it will be used both from inside `.v` files (`MetaCoq Run`) and from the extracted binary.

*Code deliverable:* `theories/Pipeline.v` compiles.

*Test deliverable (L1):* `test/TestPipeline.v`:
```
From Hallmark Require Import Pipeline.
From HallmarkExamples Require Import Allowed.

MetaCoq Run (hallmark_pipeline "allowed").
```
If the pipeline fails, the file does not compile.

== Step 3.6 — Extract to OCaml <sec-step-3-6>

Create `extraction/Extract.v` that extracts the pure translation functions to OCaml:

```
From Hallmark Require Import Clause Telescope Classify Translate Emit.
Require Import ExtrOcamlBasic ExtrOcamlString.

Extract Inductive list => "list" [ "[]" "(::)" ].
Extract Inductive bool => "bool" [ "true" "false" ].

Extraction "Clause.ml" prolog_term clause.
Extraction "Translate.ml" translate_inductive.
Extraction "Emit.ml" print_program.
```

The dune `(rocq.extraction ...)` stanza compiles these into an OCaml library `hallmark_lib`.

*Code deliverable:* `dune build` produces the `hallmark_lib` OCaml library.

*Test deliverable (L1):* `dune build extraction/` succeeds — the extracted OCaml code compiles without errors.

== Step 3.7 — CLI binary <sec-step-3-7>

Build the `hallmark` executable in `bin/hallmark.ml`.
The binary is a thin OCaml wrapper that orchestrates `rocq compile` to run the pipeline:

```
hallmark compile examples/Allowed.v -n allowed -o allowed.pl
```

=== Architecture

The binary:
1. Parses CLI arguments with `cmdliner`: input `.v` file, inductive name (`-n`), output `.pl` file (`-o`), and optional Rocq load-path flags (`-Q`, `-R`, passthrough).
2. Generates a temporary driver `.v` file:
   ```
   From Hallmark Require Import Pipeline.
   Require Import Allowed.
   MetaCoq Run (hallmark_pipeline "allowed").
   ```
3. Invokes `rocq compile` on the driver file with Rocq's feedback output captured.
   The Prolog text emitted via `tmMsg` appears in the compiler's message output.
4. Parses the Prolog text from the captured output (delimited by `%%HALLMARK_BEGIN%%` / `%%HALLMARK_END%%` markers inserted by the pipeline).
5. Writes the extracted text to the output `.pl` file.
6. Cleans up the temporary file.

=== Error handling

- If `rocq compile` fails (exit code ≠ 0), the binary prints Rocq's error output and exits with code 1.
- If the inductive is not found, the `tmFail` in the pipeline causes a compilation error, surfaced to the user.
- If the output markers are missing, the binary reports a parsing error.

*Code deliverable:* `dune build` produces the `hallmark` binary.

*Test deliverable (L2):* A dune `(rule ...)` that invokes the binary and validates the output:
```
(rule
 (alias runtest)
 (deps (:v ../examples/Allowed.v)
       (:bin ../bin/hallmark.exe))
 (targets allowed.pl)
 (action
  (progn
   (run %{bin} compile %{v} -n allowed -o %{targets})
   (run swipl -g "consult('allowed.pl'), allowed(admin, r), halt(0)"
              -t "halt(1)"))))
```

== Step 3.8 — End-to-end plunit via binary <sec-step-3-8>

Wire the Prolog integration tests to use the `hallmark` binary as the generator.
The dune build first runs the binary to produce `gen/allowed.pl`, then runs the `plunit` test suite against it.

*Code deliverable:* `test/prolog/dune` updated with binary-driven generation rules.

*Test deliverable (L2):* `test/prolog/test_allowed.pl`:
```
:- use_module(library(plunit)).
:- consult('allowed.pl').

:- begin_tests(allowed_basic).

test(loads) :- true.

test(admin_all_resources) :-
    allowed(admin, secret_report).

test(delegate_via_manager) :-
    allowed(eve, secret_report).

test(unknown_user_fails, [fail]) :-
    allowed(stranger, secret_report).

test(rule_tag_present) :-
    clause(allowed(admin, _), Body),
    Body = (rule(admin_all), _).

:- end_tests(allowed_basic).
```

Dune stanza in `test/prolog/dune`:
```
(rule
 (deps (:v ../../examples/Allowed.v)
       (:bin ../../bin/hallmark.exe))
 (targets allowed.pl)
 (action (run %{bin} compile %{v} -n allowed -o %{targets})))

(rule
 (alias runtest)
 (deps test_allowed.pl allowed.pl)
 (action (run swipl -g run_tests -t halt %{dep:test_allowed.pl})))
```

This is the *first green-light moment*: a user runs `hallmark compile Allowed.v -n allowed -o allowed.pl` and gets a working Prolog rules engine, validated by automated tests.
