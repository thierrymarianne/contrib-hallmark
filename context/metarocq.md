# MetaRocq (formerly MetaCoq)

## Overview

MetaRocq is a project that formalizes the meta-theory of Rocq (Coq) inside Rocq itself.
It provides a specification of the Calculus of Inductive Constructions (CIC) as a Rocq inductive type, together with verified type-checkers, erasure procedures, and program transformations — all proven correct within Rocq.
Renamed from MetaCoq following the Coq → Rocq transition.

## Goals

- Give a **machine-checked specification** of what Rocq's kernel actually accepts: typing rules, reduction, conversion, global environments, inductives, universes.
- Build **verified tools** (type-checker, erasure, template polymorphism elimination) whose correctness is a theorem in Rocq rather than a matter of trust.
- Enable **certified meta-programming**: write Rocq plugins and transformations that come with formal guarantees.

## Architecture

MetaRocq is organized into several layers:

### Template-Rocq

- The raw AST representation, close to Rocq's internal `constr` type.
- Includes template polymorphism (universe polymorphism via template).
- Serves as the entry point: Rocq terms are **quoted** into this representation.

### PCUIC (Polymorphic Cumulative Universe-polymorphic Inductive Calculus)

- A cleaned-up, well-scoped representation of CIC terms.
- De Bruijn indices, explicit universe instances, cumulative inductives.
- This is the level where most meta-theory is developed and proofs are carried out.
- Key metatheorems proved here: **subject reduction**, **confluence**, **canonicity**, **consistency**.

### Safe Checker

- A type-checker for PCUIC terms, written in Rocq and **verified correct** against the typing specification.
- Can be extracted to OCaml and run as a standalone kernel.
- Demonstrates that Rocq's type system is decidable (for well-formed inputs).

### Erasure (ErasedRocq)

- A verified **extraction** pipeline: removes types, proofs, and propositional content from terms, producing an untyped lambda calculus suitable for execution.
- Correctness theorem: if the original term reduces to a value, the erased term reduces to the corresponding erased value.
- Goes further than Rocq's built-in extraction by being formally verified end-to-end.

### Quoting and Unquoting

- `tmQuoteRec`: recursively quotes a Rocq term and its dependencies into the Template-Rocq AST.
- `tmUnquote` / `tmMkDefinition`: splices a Template-Rocq AST back into the Rocq environment.
- This forms the basis for **reflective meta-programming** — Rocq programs that generate or transform other Rocq programs.

## Key results proved

| Result              | Meaning                                                         |
|---------------------|-----------------------------------------------------------------|
| Subject reduction   | Typing is preserved under reduction.                            |
| Confluence          | All reduction sequences converge.                               |
| Canonicity          | Closed terms of inductive type reduce to a constructor.         |
| Consistency         | `False` is not provable (no closed proof term of type `False`). |
| Checker correctness | The verified type-checker accepts exactly the well-typed terms. |
| Erasure correctness | Erased programs simulate the computational behavior of source terms. |

## TemplateMonad

- A monadic interface for meta-programs that interact with the Rocq environment at elaboration time.
- Operations: look up definitions, add new definitions, quote/unquote, resolve names, manipulate universes.
- Used to write **plugins in Rocq** rather than in OCaml, with the plugin's behavior subject to Rocq's own guarantees.

## Relation to other work

- **Lean 4 meta-programming**: Lean exposes its elaborator monad natively; MetaRocq achieves similar capabilities via quoting and TemplateMonad, but with verified foundations.
- **Agda reflection**: Agda's reflection mechanism is simpler but unverified; MetaRocq's approach provides correctness proofs for transformations.
- **CertiCoq**: a verified compiler from Rocq (Gallina) to C. Uses MetaRocq's erasure as its front end, forming a verified pipeline from proofs to executables.
- **ConCert**: verified smart contract framework built on MetaRocq's extraction and transformation infrastructure.

## Practical uses

- **Certified code generation**: extract programs with a verified erasure pipeline (stronger guarantees than Rocq's built-in extraction).
- **Proof automation**: write tactic-like meta-programs in Gallina that inspect and synthesize proof terms.
- **Language experimentation**: modify the CIC specification (add features, restrict rules) and re-verify the meta-theory.
- **Auditing**: use the safe checker as an independent, verified kernel to cross-check Rocq's own type-checking.

## Project coordinates

- Main developers: Matthieu Sozeau, Yannick Forster, and collaborators.
- Built on top of standard Rocq; installable via opam (`coq-metacoq` / `coq-metarocq` packages).
- The codebase is large (~100k lines of Rocq) and tracks recent Rocq releases.
