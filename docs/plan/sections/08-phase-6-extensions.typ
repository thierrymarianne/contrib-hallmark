= Phase 6 — Extensions <sec-phase-6>

Each extension is independent; they can be developed in any order once the core pipeline (Phases 1–3) is stable.
Every extension adds both Rocq-side tests (L1) and Prolog integration tests (L2).

== CLP Extensions

=== Step 6.1 — `Emittable` typeclass <sec-step-6-1>

Define the `Emittable` typeclass in `theories/Emittable.v`:

```
Class Emittable (P : Prop) := {
  emit : string;
}.
```

*Code deliverable:* `theories/Emittable.v` compiles.

*Test deliverable (L1):* `test/TestEmittable.v`:
```
Instance trivial_emittable : Emittable True := { emit := "true" }.
Example trivial_emits : emit = "true" := eq_refl.
```

=== Step 6.2 — CLP(FD) instances <sec-step-6-2>

Provide `Emittable` instances for `le`, `lt`, `ge`, `gt` on natural numbers, emitting CLP(FD) constraints (`#=<`, `#<`, `#>=`, `#>`).

*Code deliverable:* `theories/emittable/CLPFD.v` compiles.

*Test deliverable (L1 + L2):*

L1 — `test/TestCLPFD.v`:
```
Example le_emits : @emit (3 <= 5) _ = "3 #=< 5" := eq_refl.
```

L2 — `test/prolog/test_clpfd.pl` loads a generated `eligible.pl` with age constraints:
```
:- begin_tests(clpfd).
test(eligible_adult) :- eligible(alice, 25).
test(minor_rejected, [fail]) :- eligible(bob, 12).
:- end_tests(clpfd).
```

=== Step 6.3 — CLP(B) instances <sec-step-6-3>

Provide `Emittable` instances for boolean operations, emitting `sat(A * B)`, `sat(A + B)`, `sat(~A)`.

*Code deliverable:* `theories/emittable/CLPB.v` compiles.

*Test deliverable (L1 + L2):*

L1 — `test/TestCLPB.v` with string equality assertions.

L2 — `test/prolog/test_clpb.pl` with a feature-flag inductive:
```
:- begin_tests(clpb).
test(premium_access) :- feature_access(alice, dashboard, 1, 0).
test(no_access, [fail]) :- feature_access(bob, dashboard, 0, 0).
:- end_tests(clpb).
```

=== Step 6.4 — CLP(Q/R) instances <sec-step-6-4>

Provide `Emittable` instances for rational/real comparisons, emitting `{X =< Y}` etc.

*Code deliverable:* `theories/emittable/CLPQR.v` compiles.

*Test deliverable (L1 + L2):*

L1 — `test/TestCLPQR.v` with string equality assertions.

L2 — `test/prolog/test_clpqr.pl` with a budget constraint inductive:
```
:- begin_tests(clpqr).
test(within_budget) :- within_budget(project_a, 50000, 45000).
test(over_budget, [fail]) :- within_budget(project_b, 50000, 60000).
:- end_tests(clpqr).
```

=== Step 6.5 — Translator integration <sec-step-6-5>

Modify `translate_constructor` to check for `Emittable` instances on each premise.
If found, use `emit` instead of the default atom translation.

*Code deliverable:* `theories/Translate.v` extended.

*Test deliverable (L1):* `test/TestTranslate.v` (additional examples):
```
Example eligible_body_has_clpfd :
  let clauses := translate_inductive eligible_mib in
  existsb (fun c =>
    existsb (fun a => is_substring "#=<" (print_term a)) (cl_body c)
  ) clauses = true
:= eq_refl.
```

== Negation

=== Step 6.6 — Decidability-guarded negation <sec-step-6-6>

Extend the translator to handle `~ P` premises.
Emit `\+ p(...)` only when a `Decidable P` instance exists.
Produce a clear error (via `tmFail`) when the instance is missing.

*Code deliverable:* `theories/Translate.v` extended.

*Test deliverable (L1 + L2):*

L1 — `test/TestNegation.v`:
```
Example revoked_negation :
  let clauses := translate_inductive safe_allowed_mib in
  existsb (fun c =>
    existsb (fun a => is_prefix "\\+" (print_term a)) (cl_body c)
  ) clauses = true
:= eq_refl.
```

L2 — `test/prolog/test_negation.pl`:
```
:- begin_tests(negation).
test(not_revoked_passes) :- safe_allowed(alice, report).
test(revoked_fails, [fail]) :- safe_allowed(alice, classified).
:- end_tests(negation).
```

=== Step 6.7 — Stratification check <sec-step-6-7>

Implement `check_stratification : list clause -> bool` that builds a dependency graph, assigns strata, and rejects negative cycles.

*Code deliverable:* `theories/Stratification.v` compiles.

*Test deliverable (L1):* `test/TestStratification.v`:
```
Example stratified_allowed :
  check_stratification safe_allowed_clauses = true := eq_refl.

Example unstratified_cycle :
  check_stratification cyclic_neg_clauses = false := eq_refl.
```

== Tabling

=== Step 6.8 — Tabling directives <sec-step-6-8>

Emit `:- table pred/arity.` directives when a `Tableable` typeclass instance is registered.

*Code deliverable:* `theories/Emit.v` extended; `theories/Tableable.v` defines the typeclass.

*Test deliverable (L1 + L2):*

L1 — `test/TestTabling.v`:
```
Example tabled_output :
  is_substring ":- table allowed/2."
    (print_program_with_directives allowed_clauses) = true
:= eq_refl.
```

L2 — `test/prolog/test_tabling.pl`:
```
:- begin_tests(tabling).
test(cyclic_terminates, [nondet]) :-
    path(a, c).
test(tabled_no_loop, [nondet]) :-
    allowed(admin, report).
:- end_tests(tabling).
```

=== Step 6.9 — `tnot/1` for tabled negation <sec-step-6-9>

When tabling and negation are both active, emit `tnot(p(...))` instead of `\+ p(...)`.

*Code deliverable:* `theories/Emit.v` extended.

*Test deliverable (L2):* `test/prolog/test_tnot.pl`:
```
:- begin_tests(tnot).
test(tabled_negation_terminates) :-
    safe_allowed_tabled(alice, report).
test(tabled_negation_fails, [fail]) :-
    safe_allowed_tabled(alice, classified).
:- end_tests(tnot).
```

== Composition

=== Step 6.10 — Mutual inductives <sec-step-6-10>

Extend `translate_inductive` to handle `mutual_inductive_body` with multiple `ind_bodies`.

*Code deliverable:* `theories/Translate.v` extended.

*Test deliverable (L1 + L2):*

L1 — `test/TestMutual.v`:
```
Example mutual_produces_both :
  let clauses := translate_inductive auth_mutual_mib in
  (existsb (fun c => is_prefix "authenticated" (print_term (cl_head c))) clauses) &&
  (existsb (fun c => is_prefix "authorized" (print_term (cl_head c))) clauses) = true
:= eq_refl.
```

L2 — `test/prolog/test_mutual.pl`:
```
:- begin_tests(mutual).
test(authenticated_then_authorized) :-
    authenticated(alice, token_123),
    authorized(alice, read, document).
:- end_tests(mutual).
```

=== Step 6.11 — Parameterized inductives <sec-step-6-11>

Support inductives parameterized by typeclass-abstracted predicates.

*Code deliverable:* `theories/Translate.v` extended.

*Test deliverable (L1 + L2):*

L1 — `test/TestParameterized.v`:
```
Example parameterized_compiles :
  length (translate_inductive param_auth_mib) > 0 = true := eq_refl.
```

L2 — `test/prolog/test_parameterized.pl` with two providers:
```
:- begin_tests(parameterized).
test(ldap_provider) :- authorized_ldap(alice, read, doc).
test(oauth_provider) :- authorized_oauth(alice, read, doc).
:- end_tests(parameterized).
```

=== Step 6.12 — Multi-file emission <sec-step-6-12>

Emit multiple inductives into separate `.pl` files with `:- consult(...)` directives.

*Code deliverable:* `theories/Emit.v` extended.

*Test deliverable (L2):* `test/prolog/test_multifile.pl`:
```
:- begin_tests(multifile).
test(cross_file_query) :-
    consult('../../gen/auth_provider.pl'),
    consult('../../gen/authorized.pl'),
    authorized(alice, read, doc).
:- end_tests(multifile).
```
