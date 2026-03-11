= Phase 2 — Core Translation <sec-phase-2>

This phase builds the heart of Hallmark: the translation from MetaRocq constructor types to an internal clause representation.
Each step handles one aspect of constructor analysis.
All tests are Layer 1 (Rocq compilation): the test files assert concrete equalities via `eq_refl`, so a wrong result is a build failure.

== Step 2.1 — Define the clause IR <sec-step-2-1>

Define an inductive type `clause` in `theories/Clause.v` that represents a Prolog clause in Rocq:

```
Inductive prolog_term :=
  | PVar   : nat -> prolog_term
  | PAtom  : string -> prolog_term
  | PApp   : string -> list prolog_term -> prolog_term.

Record clause := {
  cl_name : string;
  cl_head : prolog_term;
  cl_body : list prolog_term;
}.
```

The IR must support variables (de Bruijn or named), atoms, and compound terms.

*Code deliverable:* `theories/Clause.v` compiles.

*Test deliverable (L1):* `test/TestClause.v` — manually construct the clause for `admin_all` and assert field access:
```
Example admin_clause_name :
  cl_name admin_all_clause = "admin_all" := eq_refl.
```

== Step 2.2 — Parse `tProd` telescopes <sec-step-2-2>

Write `theories/Telescope.v` with `parse_telescope : term -> list (aname * term) * term` that unfolds a chain of `tProd` binders into a list of bindings and a return type.

*Code deliverable:* `theories/Telescope.v` compiles.

*Test deliverable (L1):* `test/TestTelescope.v`:
```
Example delegate_telescope_length :
  let '(binds, _) := parse_telescope delegate_type in
  length binds =? 5 = true
:= eq_refl.

Example delegate_return_type_is_app :
  let '(_, ret) := parse_telescope delegate_type in
  match ret with tApp _ _ => true | _ => false end = true
:= eq_refl.
```

== Step 2.3 — Classify bindings <sec-step-2-3>

Write `theories/Classify.v` with `classify_binding : kername -> aname * term -> binding_class` where `binding_class` is one of:
- `BIndex` — universally quantified variable appearing in the conclusion.
- `BRecursive` — premise whose type is an application of the inductive being defined.
- `BExternal` — premise whose type is an application of a different predicate.
- `BErased` — `Type`/`Prop`/sort parameter, not emitted.

*Code deliverable:* `theories/Classify.v` compiles.

*Test deliverable (L1):* `test/TestClassify.v`:
```
Example delegate_has_recursive :
  existsb (fun c => match c with BRecursive _ => true | _ => false end)
    (classify_all allowed_kn delegate_bindings) = true
:= eq_refl.

Example delegate_has_external :
  existsb (fun c => match c with BExternal _ => true | _ => false end)
    (classify_all allowed_kn delegate_bindings) = true
:= eq_refl.
```

== Step 2.4 — Extract the conclusion <sec-step-2-4>

Write `extract_conclusion : kername -> term -> option prolog_term` in `theories/Translate.v` that converts the return type of a constructor (after stripping `tProd`s) to a `prolog_term`.

*Code deliverable:* `theories/Translate.v` compiles (partial — conclusion extraction only).

*Test deliverable (L1):* `test/TestTranslate.v`:
```
Example admin_all_conclusion :
  extract_conclusion allowed_kn admin_all_ret =
  Some (PApp "allowed" [PAtom "admin", PVar 0])
:= eq_refl.
```

== Step 2.5 — Extract body atoms <sec-step-2-5>

Add `extract_body : kername -> list (binding_class) -> list prolog_term` to `theories/Translate.v`.
Recursive and external premises become `PApp` terms; index variables and erased bindings are skipped.

*Code deliverable:* `theories/Translate.v` extended.

*Test deliverable (L1):* `test/TestTranslate.v` (additional examples):
```
Example delegate_body_length :
  length (extract_body allowed_kn delegate_classified) = 2
:= eq_refl.
```

== Step 2.6 — Assemble clauses <sec-step-2-6>

Combine previous steps into `translate_constructor : kername -> ident * term -> option clause` in `theories/Translate.v`:
1. Parse the telescope (Step 2.2).
2. Classify each binding (Step 2.3).
3. Extract the conclusion as clause head (Step 2.4).
4. Extract body atoms (Step 2.5).
5. Wrap in a `clause` record with the constructor name.

*Code deliverable:* `theories/Translate.v` feature-complete for single constructors.

*Test deliverable (L1):* `test/TestTranslate.v`:
```
Example translate_admin_all :
  match translate_constructor allowed_kn admin_all_ctor with
  | Some c => (cl_name c =? "admin_all")%string
  | None => false
  end = true
:= eq_refl.

Fail Example translate_bad_ctor :
  translate_constructor allowed_kn bad_ctor = Some _ := eq_refl.
```

== Step 2.7 — Translate a full inductive <sec-step-2-7>

Write `translate_inductive : mutual_inductive_body -> list clause` that maps `translate_constructor` over all constructors.
Handle `ind_npars` to skip type parameters.

*Code deliverable:* `theories/Translate.v` feature-complete.

*Test deliverable (L1):* `test/TestTranslate.v`:
```
Example allowed_produces_three_clauses :
  match find_inductive allowed_program (kn_of "allowed") with
  | Some mib => length (translate_inductive mib) =? 3
  | None => false
  end = true
:= eq_refl.
```
This is the integration test for Phase 2: it exercises the full pipeline from quoted AST to clause list.
