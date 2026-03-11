# Prolog as a Backward-Chaining Rules Engine

## Forward vs backward chaining

- **Forward chaining** (data-driven): starts from known facts, repeatedly applies rules to derive new facts until the goal is reached or no more rules fire. Used in production rule systems (OPS5, CLIPS, Drools).
- **Backward chaining** (goal-driven): starts from a goal and works backwards, looking for rules whose head matches the goal and recursively trying to satisfy their body. This is exactly what Prolog does natively.

Backward chaining is efficient when the goal space is small relative to the fact space — it avoids deriving irrelevant facts.

## Prolog's execution as backward chaining

Prolog's SLD resolution is backward chaining by construction:

1. A **goal** is posed (the query).
2. The engine finds a rule whose **head** unifies with the goal.
3. The rule's **body** becomes a new set of sub-goals.
4. Each sub-goal is recursively resolved the same way.
5. Facts (rules with empty bodies) are base cases that terminate the chain.

This means any Prolog program is already a backward-chaining rules engine — no additional framework is needed.

## Anatomy of a rules engine in Prolog

### Knowledge base (facts)

```prolog
symptom(patient_1, fever).
symptom(patient_1, cough).
symptom(patient_1, fatigue).
symptom(patient_2, headache).
symptom(patient_2, stiff_neck).
lab_result(patient_1, crp, high).
```

### Rules (inference)

```prolog
suspects(Patient, flu) :-
    symptom(Patient, fever),
    symptom(Patient, cough),
    symptom(Patient, fatigue).

suspects(Patient, meningitis) :-
    symptom(Patient, headache),
    symptom(Patient, stiff_neck).

requires_test(Patient, blood_culture) :-
    suspects(Patient, Disease),
    serious(Disease).

serious(meningitis).
```

### Query (goal)

```prolog
?- suspects(patient_1, Disease).
%  Disease = flu.

?- requires_test(patient_2, Test).
%  Test = blood_culture.
```

The engine chains backward from `requires_test` → `suspects` → individual symptoms, only exploring paths relevant to the query.

## Why Prolog excels at this

- **Unification** generalizes simple pattern matching: rules can have variables anywhere in the head, enabling polymorphic matching without explicit dispatch.
- **Backtracking** explores all applicable rules automatically, producing every valid derivation — not just the first.
- **No rule ordering dependency for correctness**: all matching clauses are tried (though order affects which answer comes first).
- **Dynamic facts** (`assert/1`, `retract/1`) allow the knowledge base to evolve at runtime — new evidence triggers new derivation paths.
- **Meta-predicates** (`findall/3`, `aggregate_all/3`) collect all solutions, enabling reasoning over sets of derivations.

## Common patterns

### Chained inference with explanation

```prolog
explains(Goal, Goal, [Goal]) :-
    fact(Goal).
explains(Goal, Conclusion, [Conclusion-by-Rule | Trace]) :-
    rule(Conclusion, Conditions, Rule),
    maplist(explains(Goal), Conditions, Traces),
    append(Traces, Trace).
```

Tracing the proof path lets the engine **explain** its reasoning — a key requirement for expert systems and auditable decision-making.

### Negation as failure for default reasoning

```prolog
eligible(X) :-
    applicant(X),
    \+ disqualified(X).
```

If `disqualified(X)` cannot be proved, the system assumes eligibility — closed-world default reasoning.

### Priority and conflict resolution

```prolog
best_diagnosis(Patient, Disease) :-
    findall(D-S, (suspects(Patient, D), severity(D, S)), Pairs),
    sort(2, @>=, Pairs, [Disease-_ | _]).
```

When multiple rules fire, gather all results and select by priority, confidence, or severity.

## Comparison with other rules engines

| System       | Chaining   | Strengths                                    |
|--------------|------------|----------------------------------------------|
| Prolog       | Backward   | Native unification, backtracking, first-class variables |
| CLIPS        | Forward    | Rete algorithm, high throughput on large fact bases |
| Drools       | Forward    | JVM integration, enterprise tooling          |
| OPA / Rego   | Backward-ish | Policy-as-code, JSON-native                |
| Datalog      | Bottom-up  | Guaranteed termination, efficient fixpoint    |

Prolog is the natural choice when the problem is goal-driven (diagnostic, advisory, configuration) rather than data-driven (monitoring, alerting, stream processing).

## Scaling considerations

- **Tabling / memoization** (`library(tabling)` in SWI-Prolog): caches intermediate results, avoids redundant recomputation, and guarantees termination for Datalog-like programs.
- **Indexing**: SWI-Prolog indexes on first argument by default; `library(jiti)` adds just-in-time indexing on deeper arguments, critical for large fact bases.
- **Modular knowledge bases**: use Prolog modules or separate fact files loaded dynamically to partition large rule sets.
- **Incremental assertion**: `assert/1` facts as new evidence arrives; backward chaining naturally incorporates them on the next query without replanning.

## Typical domains

- Medical and fault diagnosis (symptom → condition backward chaining).
- Configuration and eligibility engines (goal: is this configuration valid?).
- Access control and policy evaluation (goal: is this action permitted?).
- Legal reasoning (goal: does this case satisfy statute X?).
- Planning and advisory systems (goal: what steps achieve objective Y?).
