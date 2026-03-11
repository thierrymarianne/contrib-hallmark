# SLD Resolution Traces and Proof Witnesses for Hallmark

*Context file for the Hallmark technical document. Covers the structural correspondence between Prolog SLD resolution traces and Rocq proof terms, and how to reconstruct formal proof witnesses from execution.*

**Sources:** Wikipedia (SLD resolution, Proof-carrying code), Stony Brook CSE595 slides, Stack Overflow (Prolog meta-interpreter proof trees), SWI-Prolog prooftree.pl, Abella/Beluga project pages.

---

## 1. SLD Resolution Traces

### 1.1 What is SLD Resolution?

**SLD** (Selective Linear Definite clause resolution) is the basic inference rule used in logic programming and Prolog. It is sound and refutation-complete for Horn clauses.

Given:
- A **goal clause** (negation of the query): ¬L₁ ∨ … ∨ ¬Lᵢ ∨ … ∨ ¬Lₙ
- A **selected literal** ¬Lᵢ
- A **definite clause** L ∨ ¬K₁ ∨ … ∨ ¬Kₘ whose positive literal L unifies with Lᵢ

SLD resolution derives a new goal clause by replacing the selected literal with the negative literals of the input clause and applying the unifying substitution θ.

The name indicates:
- **S**: A selection function uniquely selects one literal to resolve upon
- **L**: The proof is a linear sequence of goal clauses
- **D**: All clauses are definite (one positive literal, zero or more negative)

### 1.2 The SLD Derivation Tree

An **SLD derivation tree** (or SLD tree) visualizes all possible proof paths for a query.

- **Root**: The initial goal clause (the query)
- **Nodes**: Each node is a goal clause
- **Edges**: An edge from goal G to goal G′ exists when G′ is derived from G by resolving the selected literal against some program clause C
- **Success leaves**: Nodes with the empty clause □ (refutation)
- **Failure leaves**: Non-empty goals whose selected literal unifies with no clause head

Prolog explores this tree depth-first, left-to-right (OLD resolution: Ordered Linear Definite), backtracking at failure nodes.

### 1.3 Structure of a Trace Node

Each resolution step records:

1. **Goal**: The current goal clause (conjunction of atoms to prove)
2. **Selected atom**: The literal being resolved (typically leftmost)
3. **Clause applied**: The definite clause whose head unified with the selected atom
4. **Unifying substitution (MGU)**: The substitution θ that made head and goal match
5. **Derived goal**: The new goal after replacing the selected literal with the clause body, with θ applied

A **trace** is the sequence of such steps along a single successful branch from root to □.

### 1.4 Prolog Meta-Interpreters That Capture Proof Trees

A meta-interpreter extends the standard `call/1` semantics to produce a **proof term** as output. The proof structure mirrors the derivation:

**Base case (fact):**
```prolog
prove(true, true) :- !.
prove(H, fact(H)) :- clause(H, true), !.
```

**Conjunction:**
```prolog
prove((G1, G2), (P1, P2)) :- !, prove(G1, P1), prove(G2, P2).
```

**Rule application (the key case):**
```prolog
prove(H, subproof(H, Subproof)) :-
    clause(H, Body),
    prove(Body, Subproof).
```

Here `subproof(H, Subproof)` records: we proved H by applying a clause whose head is H and whose body was proved with proof Subproof. The structure is a tree: each node is a clause application, and children are proofs of the body goals.

**SWI-Prolog's `prolog_prooftree` module** provides `proof_tree(:Goal, -Tree)` which captures the derivation tree using the trace mechanism. Each node has the form:

```
g(Frame, Level, Goal, CRef, Complete, Children)
```

- `Goal`: The goal as executed (after success)
- `CRef`: Clause reference that produced this answer
- `Children`: Child nodes (subproofs) in reverse execution order

The module uses `prolog_trace_interception/4` to hook into the execution trace and build the tree incrementally.

---

## 2. Correspondence to Rocq Proof Terms

### 2.1 Rocq Proofs as Constructor Applications

In Rocq (and Coq), a **proof of an inductive proposition** is a term built from the type's constructors. Each constructor corresponds to an introduction rule: to prove the conclusion, one must supply proofs of the premises.

For the `allowed` predicate:

```coq
Inductive allowed : user -> resource -> Prop :=
  | admin_all  : forall r, allowed admin r
  | read_public : forall u, allowed u public_doc
  | delegate   : forall u v r,
      manager_of u v -> allowed v r -> allowed u r.
```

A proof of `allowed eve secret_report` is one of:
- `admin_all secret_report` (if eve = admin)
- `read_public eve` (if secret_report = public_doc)
- `delegate eve v secret_report pf_mgr pf_allowed` for some v, where `pf_mgr : manager_of eve v` and `pf_allowed : allowed v secret_report`

The proof term is a **tree**: the root is the conclusion, and each node is a constructor application whose children are proofs of its premises.

### 2.2 The Structural Isomorphism

**Key insight**: When Prolog resolves a query against clauses generated from Rocq inductive constructors, the resolution trace structurally corresponds to a Rocq proof term.

| Prolog concept        | Rocq concept                    |
|-----------------------|---------------------------------|
| Clause application    | Constructor application         |
| Resolved atom (head)  | Conclusion of the constructor   |
| Body atoms (subgoals)| Premises of the constructor     |
| Fact (empty body)     | Constructor with no premises     |
| Trace node            | Proof term node                 |

The tree structure is identical: premises become subgoals, and the conclusion is the resolved atom.

### 2.3 Concrete Example

Query: `allowed(eve, secret_report)`.

Assume:
- `manager_of(eve, admin)` is a fact
- `allowed(admin, secret_report)` holds (e.g. via `admin_all`)

**Prolog resolution trace:**
1. Goal: `allowed(eve, secret_report)`
2. Resolve with `allowed(U, R) :- manager_of(U, V), allowed(V, R)` (from `delegate`)
   - MGU: U=eve, R=secret_report
   - Subgoals: `manager_of(eve, V), allowed(V, secret_report)`
3. Resolve `manager_of(eve, V)` with fact `manager_of(eve, admin)` → V=admin
4. Subgoal: `allowed(admin, secret_report)`
5. Resolve with `allowed(admin, R)` (from `admin_all`) → R=secret_report
6. Empty goal → success

**Corresponding Rocq proof term:**
```
delegate eve admin secret_report
  (manager_of_eve_admin)           (* proof of manager_of eve admin *)
  (admin_all secret_report)        (* proof of allowed admin secret_report *)
```

Each clause application in the trace maps to one constructor application in the proof term. The order of premises in the constructor matches the order of subgoals in the clause body.

### 2.4 Why the Correspondence Holds

Hallmark compiles each Rocq constructor to exactly one Prolog clause. The translation is structure-preserving:

- Constructor name → identifies which clause (we can record it during translation)
- Conclusion → clause head
- Premises → body atoms in order

Therefore, when Prolog selects a clause during resolution, it is effectively selecting a constructor. The trace records which clauses were applied; that information is sufficient to reconstruct which constructors were applied and with what arguments.

---

## 3. Reconstructing Proof Terms

### 3.1 Walking the Trace Bottom-Up

To build a Rocq proof term from an SLD trace:

1. **Start from the root** of the trace (the original query).
2. **For each node**: The node corresponds to a goal G resolved by clause C. Clause C was generated from constructor K. The proof term for G is:
   ```
   K args... (proof_1) (proof_2) ... (proof_n)
   ```
   where `args` are the index/data arguments (from the MGU) and `proof_i` is the proof term for the i-th subgoal (child node).

3. **Base case**: When the clause is a fact (no body), the proof term is `K args...` with no child proofs.

4. **Recurse**: Process children before the parent (bottom-up) so that when building the parent's term, the child proofs are already constructed.

### 3.2 Type Information from the Inductive Definition

The Hallmark translator has access to the full inductive definition via MetaRocq. For each constructor it knows:

- The constructor name
- The types of all arguments (index variables, premises)
- Which arguments are premises (proof-carrying) vs. data

This type information is used to:
- **Identify the constructor** from the clause reference (clause ↔ constructor is 1:1)
- **Order the premises** correctly (body atom order = premise order)
- **Build a well-typed term** for Rocq to type-check

### 3.3 Certification by Type-Checking

The reconstructed term can be **type-checked by Rocq** to certify correctness:

1. Emit the proof term as Rocq syntax (or a serialized representation).
2. In Rocq, state the theorem: `allowed eve secret_report`.
3. The reconstructed term should have that type.
4. Run the type-checker. If it succeeds, the proof is valid.

This provides **independent verification**: the Prolog execution and the Rocq type-checker are separate implementations. Agreement between them certifies that the trace corresponds to a valid proof.

---

## 4. Practical Value

### 4.1 Audit Trails

Every decision produced by the rules engine can be **explained** by its proof tree. For access control, compliance, or diagnostic systems:

- *Why was this user allowed?* → The proof tree shows the exact chain: e.g. `delegate` via `manager_of` and `admin_all`.
- The trace is a **complete record** of which rules fired and in what order.

### 4.2 Explainability

The proof term is a **formal justification**. Unlike heuristic or black-box systems:

- The explanation is **structurally tied** to the inference rules.
- It can be **inspected** by domain experts.
- It is **machine-readable** and can drive UI (e.g. "You were granted access because you manage Admin, who has direct access").

### 4.3 Formal Certificates

The proof term can be **exported and independently verified**:

- A third party receives: (query, answer, proof term).
- They load the inductive definition and type-check the proof term.
- No need to trust the Prolog engine or the original execution environment.

This is analogous to **proof-carrying code** (PCC): the consumer checks a small, fast proof rather than re-running the full computation.

### 4.4 Comparison to Proof-Carrying Code

| Aspect        | PCC                         | Hallmark proof witnesses           |
|---------------|-----------------------------|------------------------------------|
| What is proved | Code satisfies safety policy | Query follows from rules            |
| Proof format  | Machine-code-level proof    | Inductive proof term (Rocq)         |
| Verification  | Proof checker               | Rocq type-checker                  |
| Trust model   | Consumer need not trust producer | Consumer need not trust Prolog |

In both cases: the producer does expensive work (proof search / compilation); the consumer does cheap work (proof checking / type-checking).

---

## 5. Existing Work

### 5.1 Proof-Relevant Logic Programming

Traditional logic programming treats proofs as irrelevant: only the answer substitution matters. **Proof-relevant** (or **proof-carrying**) logic programming explicitly represents and manipulates proof objects. The correspondence between SLD derivations and proof terms is the foundation for such systems.

### 5.2 Certified Proof Search: Abella and Beluga

**Abella** (abella-prover.org) is an interactive theorem prover based on lambda-tree syntax. It uses a two-level logic: specifications in hereditary Harrop formulas (executable, λProlog-compatible), and a reasoning logic to reason about those specifications. Abella does **not** produce independently verifiable proof terms; proofs are developed interactively but not exported as certificates.

**Beluga** (McGill) is a functional language for reasoning about formal systems with HOAS. Proofs in Beluga are **recursive programs** (Curry-Howard); they can be type-checked independently. Beluga thus produces proof terms that serve as certificates. Harpoon provides tactic-based proving with more automation.

### 5.3 Lambda-Prolog and Proof Terms

**λProlog** is founded on higher-order hereditary Harrop formulas (HOHH), extending Horn clauses with implications and universal quantification in bodies. Its proof procedure builds **uniform proofs** in intuitionistic logic. The structure of proofs is more complex than first-order SLD (e.g. hypothetical reasoning), but the principle—proof search produces proof terms—carries over.

### 5.4 SWI-Prolog Proof Tree Capture

The `prolog_prooftree` module (in the ddebug pack) captures derivation trees for declarative debugging. It provides the infrastructure (trace interception, node structure) that could be adapted to emit proof witnesses for Hallmark-generated programs.

---

## References

- Wikipedia: [SLD resolution](https://en.wikipedia.org/wiki/SLD_resolution)
- Wikipedia: [Proof-carrying code](https://en.wikipedia.org/wiki/Proof-carrying_code)
- Stony Brook CSE595: Definite Logic Programs, Derivation and Proof Trees
- Stack Overflow: [Proof as output argument in Prolog meta-interpreter](https://stackoverflow.com/questions/55483479/proof-as-an-output-argument-in-prolog-meta-interpreter)
- SWI-Prolog: `prolog_prooftree` module (prooftree.pl)
- Abella: https://abella-prover.org/
- Beluga: https://complogic.cs.mcgill.ca/beluga/
