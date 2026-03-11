# Negation in Prolog and Rocq/Coq: Context for Hallmark

**Context for Hallmark** — a system compiling Rocq inductives to Prolog. This document covers Prolog's negation-as-failure, stratification, negation in Rocq/Coq, and the connection between Rocq decidability and safe Prolog negation.

**Sources:**
- [Wikipedia: Negation as failure](https://en.wikipedia.org/wiki/Negation_as_failure)
- [SWI-Prolog: Well Founded Semantics](https://www.swi-prolog.org/pldoc/man?section=WFS)
- [Rocq Core Library: Corelib.Init.Logic](https://rocq-prover.org/doc/V9.0.0/corelib/Corelib.Init.Logic.html)
- [Rocq Standard Library: Stdlib.Logic.Decidable](https://coq.inria.fr/doc/v9.0/stdlib/Stdlib.Logic.Decidable.html)
- [Clark (1978): Negation as failure](http://www.doc.ic.ac.uk/~klc/NegAsFailure.pdf)
- [Gelfond & Lifschitz (1988): Stable model semantics](https://en.wikipedia.org/wiki/Stable_model_semantics)

---

## 1. Prolog's Negation-as-Failure (`\+`)

### 1.1 How It Works

**Negation-as-failure (NAF)** is a non-monotonic inference rule: derive `not p` from the failure to prove `p`.

- **In Prolog:** `\+ Goal` succeeds if and only if `Goal` fails (finitely).
- **Rule:** If `Goal` fails → `\+ Goal` succeeds. If `Goal` succeeds → `\+ Goal` fails.

```prolog
% Example: \+ p succeeds when p fails
p :- q, \+ r.
q :- s.
q :- t.
t.

% NAF derives: not s, not r, p, t, q
```

### 1.2 The Closed World Assumption (CWA)

NAF relies on the **closed world assumption (CWA)**: anything that cannot be proven from the knowledge base is assumed false.

- The world is "closed": what is not derivable is false.
- In the non-propositional case, completion adds equality axioms: individuals with distinct names are distinct.
- NAF simulates reasoning with the **completion** of the program (Clark 1978), where `←` is interpreted as "if and only if" (≡).

### 1.3 Soundness Conditions

**Clark's completion semantics:** NAF is sound with respect to classical negation **only for ground goals** (goals with no unbound variables at evaluation time).

| Condition | Sound? |
|-----------|--------|
| Goal is ground when `\+` is evaluated | Yes |
| Goal has unbound variables | No — unsound |

**SLDNF resolution** implements this semantics but is **sound but not complete** with respect to Clark completion.

### 1.4 Non-Ground Goals: Unsoundness and Floundering

**Floundering** occurs when NAF is applied to a non-ground goal.

**Problem:** `\+ Goal` requires `Goal` to finitely fail. With unbound variables:

- **Classical logic** would interpret `p(X) :- \+ q(Y)` as: "if q fails for some Y, then p holds for all X"
- **Prolog** instead requires q to finitely fail for **every possible Y** before `\+ q(Y)` succeeds

**Examples of unsound behavior:**

```prolog
% \+ X==1 returns false when X is unbound (classical logic would require X bound first)
?- \+ X==1.
false.

% \+ X==1, X=1 succeeds in Prolog but should fail in classical logic
?- \+ X==1, X=1.
X = 1.
```

**Practical mitigation:** Use coroutining to delay negation until the goal is ground:

```prolog
when(ground(Goal), \+ Goal)
```

---

## 2. Stratification

### 2.1 Definition

**Stratification** is a property of logic programs where predicates are organized into **strata** (layers) such that:

- **No predicate negatively depends on itself through a cycle**
- Negation is only applied to predicates from **lower strata**
- Lower strata are fully evaluated before higher strata that depend on their negation

**Formally:** A program is stratified if there exists a function `level` from predicates to natural numbers such that:

- If `p` is in the body of a clause defining `q`, then `level(p) ≤ level(q)`
- If `\+ p` is in the body of a clause defining `q`, then `level(p) < level(q)`

### 2.2 Why Stratification Matters

- **Unique stable model:** Stratified programs have exactly one stable model.
- **Agreement of semantics:** Stratified negation, stable model semantics, and well-founded semantics all agree for stratified programs.
- **Computational tractability:** Stratified programs have finite, uniquely determined models and are computable.

### 2.3 SWI-Prolog Handling

- **Standard `\+`:** SWI-Prolog does not enforce stratification automatically. Unsoundness can occur with non-ground goals or non-stratified programs.
- **Tabled negation (`tnot/1`):** For programs using `table/1` and `tnot/1`, SWI-Prolog implements **Well Founded Semantics** via tabling (SLG resolution).
- **Tabled vs standard:** Unlike `\+`, `tnot/1` does not cut over the computation subtree; it evaluates ground queries soundly for Datalog programs with negation (polynomial data complexity).

---

## 3. Negation in Rocq/Coq

### 3.1 Definition of Negation

```coq
Definition not (A : Prop) := A -> False.
Notation "~A" := (not A).
```

`False` is an inductive proposition with no constructors:

```coq
Inductive False : Prop := .
```

So `~A` means "A implies False" — there is no proof of A.

### 3.2 Classical vs Constructive Negation

- **Constructive:** `~A` is `A -> False`. To prove `~A`, you assume `A` and derive `False`. No use of excluded middle.
- **Classical:** With `Classical_prop.classic` (or axiom of choice), you get `¬¬A → A` for all `A`.

### 3.3 The `Decidable` Typeclass

**Definition (Stdlib.Logic.Decidable):**

```coq
Definition decidable (P : Prop) := P \/ ~P.
```

A proposition is decidable when it can be proven or refuted.

**Decidability is preserved under connectives:** `dec_or`, `dec_and`, `dec_not`, `dec_imp`, `dec_iff`.

### 3.4 The `sumbool` Type: `{P} + {~P}`

**Informative disjunction** — a decision procedure that returns a proof:

```coq
Inductive sumbool (A B : Prop) : Set :=
  | left  : A -> {A} + {B}
  | right : B -> {A} + {B}.
```

- `{P} + {~P}` — either a proof of `P` or a proof of `~P`
- Unlike `bool`, sumbool carries **justifications**; destructing it gives hypotheses in the proof context
- Examples: `eq_nat_dec : ∀n m : nat, {n = m} + {n ≠ m}`; `Compare_dec.zerop : ∀n : nat, {n = 0} + {0 < n}`

**Extraction:** Sumbool values extract to booleans in executable code.

### 3.5 Computability Connection

A proof of `forall n, decidable (P n)` can be extracted into a recursive algorithm that decides `P n` for any input. Conversely, the termination of such an algorithm can be turned into a proof of decidability.

---

## 4. Well-Founded Negation (Brief)

### 4.1 Beyond Stratification

**Well-founded semantics** extends the treatment of negation beyond stratified programs:

- **Three-valued logic:** true, false, and **undefined** (bottom)
- Handles programs with contradictions or multiple answer sets
- Propagates "undefined" to literals that depend on unresolved subprograms

### 4.2 SWI-Prolog Support via Tabling

- **`tnot/1`:** Tabled negation; argument must be a goal of a tabled predicate
- **`library(wfs)`:** Interface to Well Founded Semantics
- **`call_delays/2`:** Returns whether a goal is true with delays (conditional answers) or unconditionally true
- **`undefined/0`:** Represents the third value (neither true nor false)

```prolog
:- table undefined/0.
undefined :- tnot(undefined).
```

For programs with cycles through negation (e.g. `p :- tnot(q). q :- tnot(p).`), the residual program may contain conditional answers and the toplevel can report `undefined`.

---

## 5. Connection: Rocq Decidability and Prolog Negation-as-Failure

### 5.1 The Key Insight

**Rocq decidability** (`decidable P` or `{P} + {~P}`) provides a **decision procedure** for `P`:

- For any input, the procedure terminates and returns either a proof of `P` or a proof of `~P`
- This is equivalent to knowing that `P` is either provable or refutable in finite time

**Prolog negation-as-failure** is sound when:

- The negated goal is **ground** at evaluation time
- The goal either **succeeds** (we have a proof) or **finitely fails** (we have a refutation)

### 5.2 When Compiling Rocq to Prolog

For Hallmark (compiling Rocq inductives to Prolog):

1. **Decidable predicates** in Rocq correspond to predicates that can be **decided** in Prolog: either they succeed or they finitely fail.

2. **Safe use of `\+`:** If a Rocq predicate `P` is decidable and its Prolog translation `p` is called with ground arguments, then:
   - `p` succeeds ↔ `P` is provable
   - `p` finitely fails ↔ `~P` is provable
   - Hence `\+ p` correctly implements `~P` in this case

3. **Stratification check:** When compiling Rocq definitions that use negation, ensure the resulting Prolog program is stratified (or use `tnot/1` with tabling for well-founded semantics).

4. **Groundness:** Ensure that any negated goal in the compiled Prolog is ground when evaluated. For inductives, this often holds when the predicate is fully applied to constructor terms.

### 5.3 Summary Table

| Rocq concept | Prolog counterpart | Condition for soundness |
|--------------|--------------------|-------------------------|
| `~P` (constructive) | `\+ p` | `p` ground when evaluated |
| `decidable P` | `p` succeeds or fails finitely | Ground arguments |
| `{P} + {~P}` (decision procedure) | `p` or `\+ p` | Same as above |
| Stratified program | No negative cycles | Use `tnot/1` or ensure stratification |

### 5.4 Practical Recommendation for Hallmark

When compiling Rocq negation to Prolog:

- **Prefer:** Only emit `\+` when the source predicate is decidable and the compiled goal is guaranteed ground.
- **Alternative:** Use `tnot/1` with tabling for programs that need well-founded semantics.
- **Avoid:** Emitting `\+` for non-ground goals or non-decidable predicates.
