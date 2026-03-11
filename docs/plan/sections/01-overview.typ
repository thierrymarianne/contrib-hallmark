= Overview <sec-overview>

Hallmark compiles Rocq inductive definitions — viewed as sets of Horn clauses via Curry–Howard — into executable Prolog programs.
The generated code functions as a backward-chaining rules engine whose soundness, consistency, and well-foundedness are inherited from Rocq's type theory.
MetaRocq provides the quoting infrastructure: it reflects inductive definitions into a term-level AST that Hallmark inspects, translates, and emits as Prolog text.

The development plan below decomposes the project into *seven phases*, each broken into fine-grained steps.
Every step produces two artifacts: a *code deliverable* and a *test deliverable* validated by `dune build @runtest`.
The project uses dune with the `(using rocq ...)` plugin for build and test orchestration, following the conventions established in the fourchette project.
@sec-testing describes the three-layer testing strategy in detail.
Steps within a phase are ordered by dependency; phases themselves are mostly sequential, though some extension work (Phase 6) can proceed in parallel once the core pipeline (Phases 1–3) is solid.

== Running example

All steps use a single running example: an access-control policy that decides whether a user is _allowed_ to access a resource.
The policy features delegation, administrative overrides, and role-based access — enough structure to exercise every part of the pipeline without being overwhelming.

```
Inductive allowed : user -> resource -> Prop :=
  | admin_all   : forall r, allowed admin r
  | read_public : forall u, public r -> allowed u r
  | delegate    : forall u d r,
      manager_of u d -> allowed d r -> allowed u r.
```

== Phase summary

#figure(
  table(
    columns: (auto, 1fr, auto),
    align: (center, left, center),
    table.header[*Phase*][*Focus*][*Steps*],
    [1], [Foundation: project setup, MetaRocq infrastructure], [1.1 – 1.5],
    [2], [Core translation: constructor analysis, clause IR], [2.1 – 2.7],
    [3], [Prolog emission, extraction, CLI binary], [3.1 – 3.8],
    [4], [Verification: property proofs over the inductive], [4.1 – 4.6],
    [5], [Proof witnesses: meta-interpreter, trace reconstruction], [5.1 – 5.5],
    [6], [Extensions: CLP, negation, tabling, composition], [6.1 – 6.12],
    [7], [Tooling: end-to-end integration, CI, docs], [7.1 – 7.5],
  ),
  caption: [Development phases and step ranges.],
) <fig-phase-summary>
