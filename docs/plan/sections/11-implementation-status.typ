= Implementation Status <sec-status>

This section records the actual state of the implementation as of March 2026, noting deviations from the original plan where the design evolved during development.

== Phase 1 — Foundation #sym.checkmark

All steps (1.1–1.5) are complete. The project skeleton, opam setup, dune build, and MetaRocq quoting infrastructure are in place.

=== Deviations

- *`QuoteAllowed.v` moved to `test/`*: originally placed in `examples/`, it was relocated to the test project to keep the examples directory clean. The test theory depends on it for quoting tests.
- *`opam_setup.sh` in `scripts/`*: the setup script lives at `scripts/opam_setup.sh` (called from `docs/setup.sh`) rather than using a `.switch` file.
- *MetaRocq imports*: the actual package names are `MetaRocq.Template`, `MetaRocq.Utils`, `MetaRocq.Common` — the plan used the older `MetaCoq` names in some examples.

== Phase 2 — Core Translation #sym.checkmark

All steps (2.1–2.7) are complete. Constructor types are parsed, classified, and assembled into `clause` records.

=== Deviations

- *`translate_constructor` signature*: takes `(Σ : global_env) (ind_kn : kername) (name : ident) (ty : term)` instead of just `(kn : kername) (name_ty : ident * term)`. The `global_env` is needed for constructor name resolution via `lookup_constructor_name`.
- *De Bruijn normalization*: `term_to_prolog` carries a `depth` counter to normalize de Bruijn indices relative to the telescope position, producing stable variable names.
- *Nullary constructor injection*: for enumeration types (e.g. `admin : user`), the constructor name is injected as an atom argument in the head: `user(admin).` instead of `user().`.
- *`Lookup.v` extended*: includes `lookup_constructor_name` in addition to `find_inductive`.

== Phase 3 — Prolog Emission and CLI Binary

Steps 3.1–3.7 are complete. Step 3.8 (plunit integration tests) is not yet implemented.

=== Deviations from original plan

==== Fact vs. rule distinction (Steps 3.1–3.2)

The original plan added `rule(name)` as the first body atom of every clause. The implementation distinguishes:
- *Ground facts* (no variables in the head, no premises): printed as `head.` with no audit tag.
- *Rules* (variables in the head or premises present): printed as `head :- rule(name), body.` for traceability.

A `has_var : prolog_term -> bool` function detects whether a term contains variables, driving this distinction.

==== Module-level pipeline (Step 3.5)

The `hallmark_pipeline` function from the plan was replaced by `hallmark_module (mod_name : qualid) : TemplateMonad string`, which translates _all_ inductives in a module at once:

1. `tmQuoteModule` obtains a `list global_reference` for the module.
2. `filter_ind_refs` extracts `inductive` records.
3. `collect_kernames` deduplicates by `kername` (mutual inductive blocks).
4. `quote_all` loops `tmQuoteInductive` to obtain `mutual_inductive_body` for each unique kername.
5. `build_env` constructs a `global_env` from these declarations.
6. `translate_all` processes every inductive against this environment.

This avoids the single-inductive limitation and correctly populates the global environment for cross-inductive constructor name resolution.

==== CLI binary (Step 3.7)

The binary takes a *module name* as positional argument (not a fully qualified inductive path):

```
hallmark -R _build/default/theories=Hallmark \
         -R _build/default/examples=HallmarkExamples \
         HallmarkExamples.Allowed -o allowed.pl
```

Key architectural decisions realized:
- *Direct OCaml API*: links against `rocq-runtime.toplevel`, calls `Coqc.main` — no subprocess.
- *Markers in the driver*: `Pipeline.v` purely returns the Prolog string. The CLI generates a temporary `.v` driver that wraps the result in `%%HALLMARK_BEGIN%%` / `%%HALLMARK_END%%` markers via `tmMsg`.
- *`Feedback.add_feeder`*: captures Rocq feedback messages and extracts content between markers.
- *stdout redirect*: `Unix.dup2` redirects stdout to `/dev/null` during compilation, restored in `at_exit`.
- *`at_exit` handlers*: all post-compilation logic (output writing, temp file cleanup) uses `at_exit` because `Coqc.main` may call `exit` internally.
- *`cmdliner` for CLI*: `-R`/`--recursive` and `-Q`/`--qualified` accept `DIR=NAME` pairs; `-o`/`--output` specifies the output file.

==== Step 3.8 — Prolog integration tests

Not yet implemented. The plunit test suite and dune rules for SWI-Prolog validation are pending.

== Phases 4–7

Not yet started.

== File inventory

#figure(
  table(
    columns: (auto, 1fr),
    align: (left, left),
    table.header[*File*][*Role*],
    [`theories/Hallmark.v`], [Root module, re-exports core library],
    [`theories/Clause.v`], [Prolog IR: `prolog_term`, `clause`],
    [`theories/Lookup.v`], [`find_inductive`, `lookup_constructor_name`],
    [`theories/Inspect.v`], [`get_constructors` from `mutual_inductive_body`],
    [`theories/Telescope.v`], [`parse_telescope`: unfold `tProd` chains],
    [`theories/Classify.v`], [`classify_binding`: sort binders into `BIndex`/`BRecursive`/`BExternal`/`BErased`],
    [`theories/Translate.v`], [Core translation: constructor type → `clause`],
    [`theories/Emit.v`], [Pretty-print clauses as Prolog text],
    [`theories/Pipeline.v`], [`hallmark_module`: TemplateMonad orchestration],
    [`extraction/Extract.v`], [Rocq → OCaml extraction prelude],
    [`bin/hallmark.ml`], [CLI binary],
    [`examples/Allowed.v`], [Running example: access-control policy],
    [`test/QuoteAllowed.v`], [Quoting test helper],
    [`test/Test*.v`], [Layer 1 tests for each module],
  ),
  caption: [Current file inventory.],
) <fig-file-inventory>
