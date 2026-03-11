= Dependency Graph <sec-dependency-graph>

The diagram below shows the dependency structure between steps.
An arrow from A to B means "B requires A to be complete".

== Core pipeline (critical path)

The core pipeline forms a strict sequence — each step depends on the previous one:

#figure(
  table(
    columns: (auto, 1fr, auto),
    align: (center, left, center),
    table.header[*Step*][*Description*][*Depends on*],
    [1.1], [Project scaffold], [—],
    [1.2], [Define `allowed` inductive], [1.1],
    [1.3], [Quote with MetaRocq], [1.2],
    [1.4], [Extract `mutual_inductive_body`], [1.3],
    [1.5], [Inspect constructor types], [1.4],
    [2.1], [Define clause IR], [1.1],
    [2.2], [Parse `tProd` telescopes], [1.5],
    [2.3], [Classify bindings], [2.2],
    [2.4], [Extract conclusion], [2.2],
    [2.5], [Extract body atoms], [2.3],
    [2.6], [Assemble clauses], [2.1 – 2.5],
    [2.7], [Translate full inductive], [2.6],
    [3.1], [Pretty-print terms], [2.1],
    [3.2], [Pretty-print clauses], [3.1],
    [3.3], [Emit `rule/1` fact], [3.2],
    [3.4], [Assemble full program], [3.3],
    [3.5], [`TemplateMonad` pipeline], [3.4, 2.7],
    [3.6], [Extract to OCaml], [3.5],
    [3.7], [CLI binary `hallmark`], [3.6],
    [3.8], [End-to-end plunit via binary], [3.7],
  ),
  caption: [Core pipeline dependencies (Steps 1.1 – 3.8).],
) <fig-core-deps>

== Verification (independent of emission)

Property proofs depend on the running example (Step 1.2) but are otherwise independent of the translation pipeline.
They can proceed in parallel with Phases 2–3.

#figure(
  table(
    columns: (auto, 1fr, auto),
    align: (center, left, center),
    table.header[*Step*][*Description*][*Depends on*],
    [4.1], [Decidability], [1.2],
    [4.2], [Completeness], [1.2],
    [4.3], [Confluence], [1.2],
    [4.4], [Monotonicity], [1.2],
    [4.5], [Bounded depth], [1.2],
    [4.6], [Reusable typeclasses], [4.1 – 4.5],
  ),
  caption: [Verification dependencies (Steps 4.1 – 4.6).],
) <fig-verif-deps>

== Proof witnesses

Proof-witness steps depend on a working CLI binary (Step 3.7).

#figure(
  table(
    columns: (auto, 1fr, auto),
    align: (center, left, center),
    table.header[*Step*][*Description*][*Depends on*],
    [5.1], [`why/2` meta-interpreter], [3.7],
    [5.2], [`why_not/2` failure explainer], [5.1],
    [5.3], [`explain/1` renderer], [5.1],
    [5.4], [Trace-to-term reconstruction], [5.1, 1.4],
    [5.5], [Round-trip certification], [5.4],
  ),
  caption: [Proof-witness dependencies (Steps 5.1 – 5.5).],
) <fig-witness-deps>

== Extensions (parallel tracks)

Extensions branch from the core pipeline and can be developed independently.

#figure(
  table(
    columns: (auto, 1fr, auto),
    align: (center, left, center),
    table.header[*Step*][*Description*][*Depends on*],
    [6.1], [`Emittable` typeclass], [2.6],
    [6.2], [CLP(FD) instances], [6.1],
    [6.3], [CLP(B) instances], [6.1],
    [6.4], [CLP(Q/R) instances], [6.1],
    [6.5], [Translator integration], [6.1, 2.7],
    [6.6], [Decidability-guarded negation], [4.1, 2.7],
    [6.7], [Stratification check], [6.6],
    [6.8], [Tabling directives], [3.7, 4.5],
    [6.9], [`tnot/1` tabled negation], [6.6, 6.8],
    [6.10], [Mutual inductives], [2.7],
    [6.11], [Parameterized inductives], [2.7],
    [6.12], [Multi-file emission], [3.7, 6.10],
  ),
  caption: [Extension dependencies (Steps 6.1 – 6.12).],
) <fig-ext-deps>

== Tooling

Tooling steps depend on the CLI binary and at least one extension.

#figure(
  table(
    columns: (auto, 1fr, auto),
    align: (center, left, center),
    table.header[*Step*][*Description*][*Depends on*],
    [7.1], [Test harness consolidation], [3.8],
    [7.2], [CI pipeline], [7.1],
    [7.3], [CLI polish and error reporting], [3.7],
    [7.4], [Documentation and examples], [7.3],
    [7.5], [opam package], [7.4],
  ),
  caption: [Tooling dependencies (Steps 7.1 – 7.5).],
) <fig-tooling-deps>

== Suggested development order

A practical ordering that respects dependencies and maximizes early feedback:

#figure(
  table(
    columns: (auto, 1fr),
    align: (center, left),
    table.header[*Order*][*Steps*],
    [1], [1.1 → 1.2 → 1.3 → 1.4 → 1.5 _(foundation)_],
    [2], [2.1 → 2.2 → 2.3 → 2.4 → 2.5 → 2.6 → 2.7 _(translation)_],
    [3], [3.1 → 3.2 → 3.3 → 3.4 → 3.5 → 3.6 → 3.7 → 3.8 _(emission + binary)_],
    [∥], [4.1 → 4.2 → 4.3 → 4.4 → 4.5 → 4.6 _(verification, in parallel with 2–3)_],
    [4], [5.1 → 5.2 → 5.3 → 5.4 → 5.5 _(proof witnesses)_],
    [5], [6.1 → 6.2 – 6.4 ∥ 6.6 – 6.7 ∥ 6.10 – 6.11 _(extensions, parallel tracks)_],
    [6], [6.5, 6.8 – 6.9, 6.12 _(integration of extensions)_],
    [7], [7.1 → 7.2 → 7.3 → 7.4 → 7.5 _(tooling)_],
  ),
  caption: [Suggested development order. ∥ = can proceed in parallel.],
) <fig-dev-order>
