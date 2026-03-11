# Project Brief

## Purpose

Hallmark is a provably correct rules engine.
It compiles Rocq inductive definitions — which correspond to Horn clauses — into executable Prolog programs via MetaRocq.
The resulting Prolog code functions as a backward-chaining rules engine whose soundness is guaranteed by Rocq's type theory.

The document presents the design, motivation, and architecture of Hallmark.

## Core idea

Rocq inductive types, when viewed through the Curry-Howard lens, are sets of inference rules.
Each constructor is a Horn clause: the conclusion is the type being constructed, and the premises are the constructor's arguments.
MetaRocq can quote these inductives into a term-level AST, inspect their structure, and emit equivalent Prolog clauses — facts and rules — preserving the logical content.

The key insight: Rocq guarantees that the inductive definition is well-founded and consistent; the generated Prolog program inherits those properties as a sound inference engine.

## Audience

Technical readers with a solid mathematical background (French CPGE level: comfortable with propositional and first-order logic, induction, set theory, basic algebra).
Not necessarily familiar with logic programming or formal proof assistants — the document must build that knowledge from the ground up.

## Tone and Style

Formal but pedagogical.
The document is structured as a constructive progression: each section assumes only what the previous ones have established, and every new concept is motivated before it is defined.

Key stylistic principles:
- **Build the reader's knowledge incrementally.** Start from familiar logic, introduce Prolog, then type theory, then reveal the connection. Never assume prior exposure to Curry-Howard, CIC, or SLD resolution.
- **Concrete before abstract.** Every concept is illustrated with a running example (the `allowed` access-control policy) before being generalized.
- **No rhetorical questions in headings.** Titles are affirmative and descriptive.
- **Avoid "This is not X" patterns.** Prefer positive, direct phrasing ("The analogy is exact", "The pattern is general") over negation-based emphasis.
- **One sentence per source line** (semantic line breaks). Keeps diffs clean and reordering easy.
- **Code blocks are syntax-highlighted** (`coq` for Rocq, `prolog` for Prolog).
- **Formal but not dry.** The prose should read like a well-prepared lecture: precise, well-paced, and respectful of the reader's intelligence without assuming specialist knowledge.

## Key points to cover

- The correspondence between Rocq inductive constructors and Horn clauses.
- How MetaRocq's quoting and TemplateMonad enable inspecting and transforming inductive definitions at elaboration time.
- The compilation pipeline: Rocq inductive → MetaRocq AST → Prolog clause generation.
- What properties carry over from the Rocq proof to the Prolog execution (soundness, completeness bounds).
- The role of Prolog as a backward-chaining engine: goal-driven evaluation, unification, backtracking.
- Potential use of CLP extensions for richer constraint domains.
- Practical applications: certified business rules, policy engines, diagnostic systems with auditable reasoning.

## Sources

- MetaRocq project (Sozeau, Forster et al.)
- Rocq / Coq reference manual — inductive definitions and the CIC
- Kowalski's procedural interpretation of Horn clauses
- CertiCoq and ConCert as precedents for verified compilation from Rocq
- SWI-Prolog documentation (CLP libraries, tabling, indexing)
