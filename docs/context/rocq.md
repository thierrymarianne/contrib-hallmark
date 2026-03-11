# Rocq (formerly Coq)

## Overview

Rocq is an interactive theorem prover and proof assistant.
It allows users to write mathematical definitions, executable algorithms, and theorems, then develop machine-checked proofs of those theorems.
The project was renamed from Coq to Rocq in late 2024.

## Core ideas

- Based on the **Calculus of Inductive Constructions** (CIC), a powerful type theory that serves as both a programming language and a logic.
- Follows the **Curry-Howard correspondence**: proofs are programs, propositions are types. A proof of a theorem is a well-typed term inhabiting the corresponding type.
- **Constructive logic** by default — every proof of existence carries a witness. Classical reasoning is available as an opt-in axiom.
- **Dependent types** are first-class: types can depend on values, enabling very precise specifications (e.g. length-indexed vectors, sorted lists).

## Key components

- **Gallina**: the specification language used to write terms, types, and propositions.
- **Ltac / Ltac2**: tactic languages for building proofs interactively through goal-directed commands (intro, apply, rewrite, induction, etc.).
- **Vernacular**: the command language for declarations (Definition, Theorem, Proof, Qed, Module, etc.).
- **Extraction**: Rocq can extract verified Gallina programs into executable OCaml, Haskell, or Scheme code, erasing proof-only parts.

## Ecosystem

- **MathComp** (Mathematical Components): a large library of formalized algebra built on the SSReflect proof methodology.
- **Iris**: a higher-order concurrent separation logic framework, used to verify concurrent and distributed systems.
- **VST** (Verified Software Toolchain): verify C programs against Rocq specifications.
- **SerAPI / coq-lsp**: machine-readable interfaces enabling IDE integration and tooling.
- **opam**: the standard package manager, with a dedicated Rocq package repository.

## Notable achievements

- **Four Color Theorem** (Gonthier, 2005): first major computer-verified proof of a famous conjecture.
- **Feit-Thompson Theorem** (Gonthier et al., 2012): the Odd Order Theorem, ~170k lines of formalized mathematics.
- **CompCert**: a fully verified optimizing C compiler (Leroy et al.), guaranteeing that compiled code behaves exactly as the source specifies.
- **CertiKOS**: a verified concurrent operating system kernel.

## Proof workflow

1. State a theorem as a type (`Theorem`, `Lemma`).
2. Enter proof mode (`Proof.`).
3. Transform goals using tactics — each tactic step produces new sub-goals until none remain.
4. Close the proof (`Qed.` for opaque, `Defined.` for transparent/extractable).

## Relation to other provers

| Prover   | Foundation          | Automation level  |
|----------|---------------------|-------------------|
| Rocq     | CIC (constructive)  | Moderate (tactics + plugins like omega, lia) |
| Lean 4   | CIC variant         | Higher (strong automation, metaprogramming) |
| Agda     | Martin-Löf TT       | Low (proof by direct term construction) |
| Isabelle  | HOL (classical)     | High (sledgehammer, auto) |

Rocq occupies a middle ground: more automation than Agda, a more mature library ecosystem than Lean (as of now), but less out-of-the-box automation than Isabelle.
