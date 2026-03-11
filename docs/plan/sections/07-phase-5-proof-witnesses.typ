= Phase 5 — Proof Witnesses <sec-phase-5>

This phase builds the machinery for extracting proof witnesses from Prolog execution.
Tests are primarily Layer 2 (Prolog `plunit`) and Layer 3 (round-trip).

== Step 5.1 — Emit `why/2` meta-interpreter <sec-step-5-1>

Alongside the generated clauses, emit a `why/2` meta-interpreter into the `.pl` file.
The meta-interpreter builds a `proof(Goal, by(Rule, SubProofs))` term during proof search.

*Code deliverable:* `theories/Emit.v` extended; `gen/allowed.pl` contains the `why/2` predicate.

*Test deliverable (L2):* `test/prolog/test_why.pl`:
```
:- begin_tests(why).

test(why_admin, [nondet]) :-
    why(allowed(admin, secret_report), Proof),
    Proof = proof(allowed(admin, secret_report), by(admin_all, _)).

test(why_delegate, [nondet]) :-
    why(allowed(eve, secret_report), Proof),
    Proof = proof(allowed(eve, secret_report), by(delegate, SubProofs)),
    member(proof(_, by(manager_of, _)), SubProofs).

test(why_no_proof, [fail]) :-
    why(allowed(stranger, secret_report), _).

:- end_tests(why).
```

== Step 5.2 — Emit `why_not/2` failure explainer <sec-step-5-2>

Emit a `why_not/2` predicate that explains why a goal has no proof.
For each matching clause, it identifies the first failing subgoal and recurses.

*Code deliverable:* `gen/allowed.pl` contains the `why_not/2` predicate.

*Test deliverable (L2):* `test/prolog/test_why_not.pl`:
```
:- begin_tests(why_not).

test(stranger_no_clauses) :-
    why_not(allowed(stranger, secret_report), Reason),
    Reason = all_failed(_, Failures),
    is_list(Failures),
    Failures \= [].

test(succeeding_goal_has_no_why_not, [fail]) :-
    why_not(allowed(admin, secret_report), _).

:- end_tests(why_not).
```

== Step 5.3 — Emit `explain/1` renderer <sec-step-5-3>

Emit `explain/1` and `explain_not/1` that pretty-print proof trees and failure explanations.

*Code deliverable:* `gen/allowed.pl` contains the rendering predicates.

*Test deliverable (L2):* `test/prolog/test_explain.pl`:
```
:- begin_tests(explain).

test(explain_runs_without_error) :-
    why(allowed(admin, secret_report), P),
    with_output_to(string(_), explain(P)).

test(explain_not_runs_without_error) :-
    why_not(allowed(stranger, secret_report), R),
    with_output_to(string(_), explain_not(R)).

test(explain_output_contains_rule) :-
    why(allowed(admin, secret_report), P),
    with_output_to(string(S), explain(P)),
    sub_string(S, _, _, _, "admin_all").

:- end_tests(explain).
```

== Step 5.4 — Trace-to-term reconstruction <sec-step-5-4>

Write a Prolog predicate `proof_to_rocq/2` (or a Rocq function via extraction) that converts a `why/2` proof tree into a MetaRocq-compatible term representation.
Each `by(Rule, SubProofs)` becomes a constructor application.

*Code deliverable:* `theories/Reconstruct.v` or `gen/reconstruct.pl`.

*Test deliverable (L2):* `test/prolog/test_reconstruct.pl`:
```
:- begin_tests(reconstruct).

test(admin_reconstruction) :-
    why(allowed(admin, secret_report), P),
    proof_to_rocq(P, Term),
    Term = tApp(tConstruct("allowed", 0), _).

:- end_tests(reconstruct).
```

== Step 5.5 — Round-trip certification <sec-step-5-5>

Full round-trip test: Rocq → Prolog → trace → reconstruction → Rocq type-check.

*Code deliverable:* `test/roundtrip/run.sh` orchestrating the pipeline.

*Test deliverable (L3):* A dune `(rule ...)` stanza:
```
(rule
 (alias runtest)
 (deps run.sh
       (:gen ../../gen/allowed.pl)
       (:rocq ../../theories/Reconstruct.v))
 (action (run bash %{dep:run.sh})))
```

The script:
1. Runs `swipl` to query `allowed(admin, secret_report)` and capture the proof tree.
2. Feeds the tree to the reconstruction function.
3. Pipes the reconstructed term into a Rocq file.
4. Runs `dune exec -- rocq check` to verify the term type-checks as `allowed admin secret_report`.

Exit code 0 means the round-trip succeeded.
