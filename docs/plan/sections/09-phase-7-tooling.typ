= Phase 7 — Tooling and Integration <sec-phase-7>

This phase packages Hallmark for production use: test consolidation, continuous integration, CLI polish, documentation, and packaging.

== Step 7.1 — Test harness consolidation <sec-step-7-1>

At this point, the project has accumulated tests across three layers.
Consolidate them under a single `dune build @runtest` target that:

1. *Layer 1* — Compiles all `HallmarkTest` theory files (Rocq `eq_refl` assertions).
2. *Layer 2* — Runs the `hallmark` binary to generate `.pl` files, then runs all `plunit` test suites via SWI-Prolog.
3. *Layer 3* — Runs round-trip certification scripts.

Verify that `dune clean && dune build @runtest` passes from a cold start.

*Deliverable:* A single command validates the entire project. No manual steps.

*Test:* `dune build @runtest` exits with code 0.

== Step 7.2 — CI pipeline <sec-step-7-2>

Set up GitHub Actions CI with the following workflow:

```yaml
name: CI
on: [push, pull_request]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install system dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y swi-prolog opam

      - name: Setup opam switch
        run: |
          opam init --disable-sandboxing -y
          opam switch create hallmark --empty
          opam switch import hallmark.switch
          eval $(opam env)

      - name: Build
        run: |
          eval $(opam env --switch=hallmark --set-switch)
          dune build

      - name: Test
        run: |
          eval $(opam env --switch=hallmark --set-switch)
          dune build @runtest
```

Add caching for the opam switch to speed up rebuilds.

*Deliverable:* `.github/workflows/ci.yml` passes on every push.

*Test:* The CI badge is green.

== Step 7.3 — CLI polish and error reporting <sec-step-7-3>

Harden the `hallmark` binary for real-world use:

- *Subcommands:* `hallmark compile`, `hallmark check` (dry run, report supported/unsupported constructors), `hallmark list` (list inductives in a `.v` file).
- *Error messages:* actionable, with source location when possible:
  - `"Unsupported AST node tCase in constructor foo of Allowed.v"`
  - `"No Decidable instance for bar — cannot emit negation"`
  - `"Inductive 'nope' not found in Allowed.v — available: allowed, manager_of"`
- *Exit codes:* 0 = success, 1 = Rocq compilation error, 2 = translation error, 3 = CLI usage error.
- *`--verbose` flag:* print intermediate representations (quoted AST, classified bindings, clause IR) for debugging.
- *`--with-meta` flag:* include `why/2`, `why_not/2`, `explain/1` in the output.
- *Multiple inductives:* `hallmark compile Allowed.v -n allowed -n manager_of -o policy.pl`.

*Code deliverable:* `bin/hallmark.ml` extended.

*Test deliverable (L2):* `test/prolog/dune` — binary invocation tests for each flag:
```
(rule
 (alias runtest)
 (deps (:v ../../examples/Allowed.v) (:bin ../../bin/hallmark.exe))
 (action
  (progn
   (run %{bin} check %{v} -n allowed)
   (run %{bin} compile %{v} -n allowed -o /dev/null --with-meta))))

(rule
 (alias runtest)
 (deps (:bin ../../bin/hallmark.exe))
 (action
  (with-accepted-exit-codes 3
   (run %{bin} compile nonexistent.v -n x -o /dev/null))))
```

== Step 7.4 — Documentation and examples <sec-step-7-4>

Write a `README.md` with:
- Installation instructions (opam switch import + dune build).
- Quickstart: define inductive, run `hallmark compile`, load in SWI-Prolog.
- CLI reference (`hallmark compile`, `hallmark check`, flags).
- Reference of supported AST constructs and known limitations.

Provide at least three example projects in `examples/`:
1. *Access control* (`Allowed.v`) — the running example.
2. *Medical diagnosis* (`Medical.v`) — symptoms → conditions.
3. *Resource scheduling* (`Scheduling.v`) — with CLP(FD) constraints.

Each example has:
- A corresponding `plunit` test in `test/prolog/`.
- A generation rule in `test/prolog/dune` that uses the `hallmark` binary.

*Deliverable:* `README.md` and `examples/` with three working, documented examples.

*Test:* All example tests pass under `dune build @runtest`.

== Step 7.5 — opam package <sec-step-7-5>

Create `coq-hallmark.opam` with:
- Dependencies: `rocq-core`, `rocq-stdlib`, `coq-metacoq-template`, `dune`, `cmdliner`.
- Build: `["dune" "build" "-p" name "-j" jobs]`.
- Test: `["dune" "build" "@runtest" "-p" name "-j" jobs]`.
- Install: installs the `hallmark` binary, the `Hallmark` Rocq theory, and the `hallmark_lib` OCaml library.
- Synopsis and description.

*Deliverable:* `opam install ./coq-hallmark.opam` works locally, and `hallmark compile` is available on `$PATH` after installation.

*Test:* `opam install` in a fresh switch succeeds and `dune build @runtest` passes.
