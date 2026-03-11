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
The binary links directly against `rocq-runtime.toplevel` and calls `Coqc.main` as an OCaml function — no subprocess, no shell.

```
hallmark -Q theories=Hallmark -Q examples=HallmarkExamples \
  HallmarkExamples.Allowed.allowed -o allowed.pl
```

=== Architecture

The binary:
1. Parses CLI arguments with `cmdliner`: a fully qualified inductive path (e.g. `HallmarkExamples.Allowed.allowed`), output file (`-o`/`--output`), and Rocq loadpath flags (`-R`/`--recursive`, `-Q`/`--qualified` as `DIR=NAME` pairs).
2. Splits the qualified path at the last dot into module path and inductive name.
3. Generates a temporary driver `.v` file that imports the user module, calls `hallmark_pipeline`, and wraps the result in `tmMsg` with `%%HALLMARK_BEGIN%%` / `%%HALLMARK_END%%` markers.
4. Registers a `Feedback.add_feeder` listener that captures messages starting with the begin marker and extracts the Prolog content between markers.
5. Redirects stdout to `/dev/null` (via `Unix.dup2`) to suppress Rocq's own console output.
6. Calls `Coqc.main` with the loadpath flags and the driver path.
7. Since `Coqc.main` may call `exit` internally, all post-compilation logic (write output, restore stdout, clean up temp file) is registered via `at_exit` handlers.

=== Design decisions

- *Markers in the driver, not `Pipeline.v`*: `hallmark_pipeline` purely returns the Prolog string via `tmReturn`. The `tmMsg` + markers are a CLI concern injected by the generated driver, keeping `dune build` silent and the library clean.
- *`at_exit` pattern*: `Coqc.main` (via `Coqtop.start_coq`) may call `exit` on both success and error, so code after the call is unreachable. Exit handlers ensure output is written and temp files are cleaned up regardless.
- *stdout redirect*: Rocq installs its own feedback console listener. Redirecting stdout to `/dev/null` during compilation and restoring it in `at_exit` ensures only the extracted Prolog output is emitted.
- *No subprocess*: linking against `rocq-runtime.toplevel` gives direct access to Rocq's feedback system, proper OCaml exceptions, and avoids shell escaping issues.

=== Error handling

- If Rocq compilation fails, `Coqc.main` exits with a non-zero code; Rocq's error messages go to stderr (not suppressed).
- If the inductive is not found, `tmFail` in the pipeline causes a compilation error, surfaced via stderr.
- If the feedback listener captures nothing (no markers found), the binary exits silently with no output.

*Code deliverable:* `dune build` produces the `hallmark` binary.

*Test deliverable (L2):* A dune `(rule ...)` that invokes the binary and validates the output:
```
(rule
 (alias runtest)
 (deps (:bin ../bin/hallmark.exe))
 (targets allowed.pl)
 (action
  (run %{bin} -Q ../examples=HallmarkExamples
              HallmarkExamples.Allowed.allowed
              -o %{targets})))
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
 (deps (:bin ../../bin/hallmark.exe))
 (targets allowed.pl)
 (action (run %{bin} -Q ../../examples=HallmarkExamples
                     HallmarkExamples.Allowed.allowed
                     -o %{targets})))

(rule
 (alias runtest)
 (deps test_allowed.pl allowed.pl)
 (action (run swipl -g run_tests -t halt %{dep:test_allowed.pl})))
```

This is the *first green-light moment*: a user runs `hallmark HallmarkExamples.Allowed.allowed -o allowed.pl` and gets a working Prolog rules engine, validated by automated tests.
