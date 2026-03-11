= Testing Strategy <sec-testing>

Every development step produces a deliverable validated by an automated test.
Running `dune build @runtest` from the project root must exercise every test;
a step is not considered complete until its test passes in CI.

== Build system

The project uses *dune* with the `(using rocq ...)` plugin, following the same conventions as the fourchette project.
Dependencies are pinned in a `hallmark.switch` file and restored via `opam switch import`.

=== Project layout

```
hallmark/
├── dune-project
├── hallmark.switch
├── theories/
│   ├── dune                    # (rocq.theory (name Hallmark) ...)
│   ├── Clause.v
│   ├── Telescope.v
│   ├── Classify.v
│   ├── Translate.v
│   ├── Emit.v
│   ├── Pipeline.v              # TemplateMonad entry point
│   └── properties/
│       ├── Decidability.v
│       └── ...
├── extraction/
│   ├── dune                    # (rocq.extraction ...) + (library ...)
│   └── Extract.v
├── bin/
│   ├── dune                    # (executable (name hallmark) ...)
│   └── hallmark.ml             # CLI binary
├── examples/
│   ├── dune                    # (rocq.theory (name HallmarkExamples) ...)
│   └── Allowed.v
├── test/
│   ├── dune                    # (rocq.theory (name HallmarkTest) ...)
│   ├── TestTranslate.v
│   ├── TestEmit.v
│   └── prolog/
│       ├── dune                # (rule ...) stanzas for swipl tests
│       ├── test_allowed.pl
│       └── ...
└── scripts/
    └── setup.sh
```

=== Key dune stanzas

The root `dune-project`:

```
(lang dune 3.21)
(using rocq 0.11)
```

The theories library:

```
(include_subdirs qualified)
(rocq.theory
 (name Hallmark)
 (theories Stdlib MetaRocq.Template))
```

The extraction (Gallina → OCaml):

```
(rocq.extraction
 (prelude Extract)
 (extracted_modules Clause Telescope Classify Translate Emit Pipeline)
 (theories Stdlib Hallmark))

(library
 (name hallmark_lib)
 (modules Clause Telescope Classify Translate Emit Pipeline))
```

The CLI binary:

```
(executable
 (name hallmark)
 (public_name hallmark)
 (libraries hallmark_lib cmdliner))
```

The test theory:

```
(rocq.theory
 (name HallmarkTest)
 (theories Stdlib Hallmark HallmarkExamples))
```

== Test layers

Tests are organized in three layers, from fastest to slowest.

=== Layer 1 — Rocq compilation tests

Rocq is a *dependently typed* language: if a file compiles, its type-level assertions are proven correct.
This makes `dune build` itself a powerful test harness.

*What it validates:*
- Every theorem, lemma, and `Example` in the codebase type-checks.
- Property proofs (Phase 4) are *intrinsically* tests — a compiling `Decidability.v` _is_ the test for decidability.
- Translation functions produce well-typed output.

*How to write them:*
- Use `Example` to assert concrete equalities:
  ```
  Example test_parse_delegate :
    parse_telescope (type_of_delegate) =
    ([bind_u; bind_d; bind_r; bind_mgr; bind_rec], concl)
  := eq_refl.
  ```
  The `eq_refl` proof forces Rocq to compute both sides and check they are identical.
  If the function returns the wrong result, the file *fails to compile*.

- Use `Fail` to assert that ill-formed inputs are rejected:
  ```
  Fail Example bad_input :
    translate_constructor kn bad_ctor = Some _ := eq_refl.
  ```

*Dune integration:* `dune build` compiles every `.v` file in the `test/` theory.
A compilation failure is a test failure.

=== Layer 2 — Prolog integration tests (plunit)

Generated Prolog files are validated by SWI-Prolog's built-in `plunit` test framework.
Each test file loads the generated `.pl` file and asserts queries.

*What it validates:*
- The generated Prolog is syntactically valid (loads without errors).
- Expected queries succeed.
- Expected failures indeed fail.
- The `why/2` meta-interpreter produces the expected proof tree structure.

*Test file pattern:*

```
:- use_module(library(plunit)).
:- consult('allowed.pl').

:- begin_tests(allowed).

test(admin_access) :-
    allowed(admin, secret_report).

test(delegate_access) :-
    allowed(eve, secret_report).

test(no_access, [fail]) :-
    allowed(stranger, secret_report).

test(why_admin, [true(Rule == admin_all)]) :-
    why(allowed(admin, secret_report),
        proof(_, by(Rule, _))).

:- end_tests(allowed).
```

*Dune integration:* A `(rule ...)` stanza in `test/prolog/dune` runs swipl:

```
(rule
 (alias runtest)
 (deps test_allowed.pl
       (:gen %{project_root}/gen/allowed.pl))
 (action (run swipl -g run_tests -t halt %{dep:test_allowed.pl})))
```

=== Layer 3 — Round-trip tests

End-to-end tests that exercise the full pipeline: define an inductive in Rocq, compile to Prolog via Hallmark, run queries in SWI-Prolog, capture proof trees, and (optionally) reconstruct Rocq proof terms.

*Dune integration:* A shell script orchestrates the steps; a `(rule ...)` stanza with `(alias runtest)` triggers it.

== Test naming conventions

- Rocq test files: `Test<Module>.v` (e.g., `TestTranslate.v`, `TestEmit.v`).
- Prolog test files: `test_<predicate>.pl` (e.g., `test_allowed.pl`).
- Each test file maps 1-to-1 to a development module or example.

== Coverage policy

Every step in this plan specifies its *test deliverable* alongside its *code deliverable*.
The table below summarizes which test layer validates each phase.

#figure(
  table(
    columns: (auto, 1fr, auto),
    align: (center, left, center),
    table.header[*Phase*][*Focus*][*Test layer*],
    [1], [Foundation: dune, MetaRocq quoting], [L1],
    [2], [Core translation: constructor → clause IR], [L1],
    [3], [Prolog emission: clause IR → `.pl` file], [L1 + L2],
    [4], [Verification: property proofs], [L1],
    [5], [Proof witnesses: meta-interpreter, reconstruction], [L2 + L3],
    [6], [Extensions: CLP, negation, tabling, composition], [L1 + L2],
    [7], [Tooling: CI, packaging], [L1 + L2 + L3],
  ),
  caption: [Test layers per phase.],
) <fig-test-layers>
