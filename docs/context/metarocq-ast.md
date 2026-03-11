# MetaRocq 1.4.1+9.1 — API Reference

Source: installed opam files at `~/.opam/hallmark/lib/coq/user-contrib/MetaRocq/`

## Identifiers & Names (Common/Kernames.v, Common/BasicAst.v)

```coq
Definition ident   := string.
Definition dirpath  := list ident.

Inductive modpath :=
| MPfile  (dp : dirpath)
| MPbound (dp : dirpath) (id : ident) (i : nat)
| MPdot   (mp : modpath) (id : ident).

Definition kername := modpath × ident.

Record inductive := mkInd {
  inductive_mind : kername;
  inductive_ind  : nat }.

Inductive name : Set := nAnon | nNamed (_ : ident).

Record binder_annot (A : Type) := mkBindAnn {
  binder_name : A;
  binder_relevance : relevance }.

Definition aname := binder_annot name.
```

## Term AST (Template/Ast.v)

```coq
Inductive term : Type :=
| tRel       (n : nat)
| tVar       (id : ident)
| tEvar      (ev : nat) (args : list term)
| tSort      (s : sort)
| tCast      (t : term) (kind : cast_kind) (v : term)
| tProd      (na : aname) (ty : term) (body : term)
| tLambda    (na : aname) (ty : term) (body : term)
| tLetIn     (na : aname) (def : term) (def_ty : term) (body : term)
| tApp       (f : term) (args : list term)
| tConst     (c : kername) (u : Instance.t)
| tInd       (ind : inductive) (u : Instance.t)
| tConstruct (ind : inductive) (idx : nat) (u : Instance.t)
| tCase      (ci : case_info) (type_info : predicate term)
              (discr : term) (branches : list (branch term))
| tProj      (proj : projection) (t : term)
| tFix       (mfix : mfixpoint term) (idx : nat)
| tCoFix     (mfix : mfixpoint term) (idx : nat)
| tInt       (i : PrimInt63.int)
| tFloat     (f : PrimFloat.float)
| tString    (s : PrimString.string)
| tArray     (u : Level.t) (arr : list term) (default : term) (type : term).
```

Key: **`tProd na ty body`** is `forall (na : ty), body` — the telescope we must parse.

## Environment Records (Common/Environment.v)

### constructor_body

```coq
Record constructor_body := {
  cstr_name    : ident;
  cstr_args    : context;          (* ind_bodies ,,, ind_params |- cstr_args *)
  cstr_indices : list term;
  cstr_type    : term;             (* ind_bodies |- cstr_type (full type) *)
  cstr_arity   : nat;
}.
```

### one_inductive_body

```coq
Record one_inductive_body := {
  ind_name      : ident;
  ind_indices   : context;
  ind_sort      : Sort.t;
  ind_type      : term;            (* full type of the inductive *)
  ind_kelim     : allowed_eliminations;
  ind_ctors     : list constructor_body;
  ind_projs     : list projection_body;
  ind_relevance : relevance;
}.
```

### mutual_inductive_body

```coq
Record mutual_inductive_body := {
  ind_finite    : recursivity_kind;
  ind_npars     : nat;             (* number of parameters, no let-ins *)
  ind_params    : context;         (* parameter context, with let-ins *)
  ind_bodies    : list one_inductive_body;
  ind_universes : universes_decl;
  ind_variance  : option (list Universes.Variance.t);
}.
```

### global_decl / global_env

```coq
Inductive global_decl :=
| ConstantDecl  : constant_body -> global_decl
| InductiveDecl : mutual_inductive_body -> global_decl.

Definition global_declarations := list (kername * global_decl).

Record global_env := mk_global_env {
  universes      : ContextSet.t;
  declarations   : global_declarations;
  retroknowledge : Retroknowledge.t;
}.

Definition lookup_env (Σ : global_env) (kn : kername) : option global_decl :=
  lookup_global Σ.(declarations) kn.
```

### program (Template/Ast.v)

```coq
(* From Template/Ast.v, exported via Env module *)
(* program = global_env * term *)
```

Note: `program` is used as a `Notation` or `Definition` for `(global_env * term)`.

## TemplateMonad (Template/TemplateMonad/Core.v)

```coq
(* Core constructors *)
tmReturn : forall {A}, A -> TemplateMonad A
tmBind   : forall {A B}, TemplateMonad A -> (A -> TemplateMonad B) -> TemplateMonad B
tmFail   : forall {A}, string -> TemplateMonad A

(* Quoting *)
tmQuoteRec {A} (a : A) : TemplateMonad program
  (* = tmQuoteRecTransp a true — quotes all dependencies *)

(* Defining *)
tmDefinition (id : ident) {A} (t : A) : TemplateMonad A
  (* Creates a transparent definition in the environment *)

(* Monadic notation: use >>= and ;; after importing monad notations *)
(* Or call tmBind directly *)

(* Vernacular command to run a TemplateMonad action: *)
(* MetaRocq Run <tm>. *)
```

### Important: ident is bytestring

`tmDefinition` takes an `ident` which is `string` (a bytestring).
Use `"name"%bs` notation for bytestring literals.

## Context (Common/BasicAst.v)

```coq
Record context_decl := mkdecl {
  decl_name : aname;
  decl_body : option term;   (* None for assumptions, Some for let-ins *)
  decl_type : term;
}.

(* context = list context_decl *)
(* Notation: vass na ty = {| decl_name := na; decl_body := None; decl_type := ty |} *)
(* Notation: vdef na b ty = {| decl_name := na; decl_body := Some b; decl_type := ty |} *)
```

## Kername Equality (Common/Kernames.v, Utils/ReflectEq.v)

**GOTCHA:** Do NOT pattern-match kername pairs manually. Use the provided `eqb`.

```coq
(* From MetaRocq.Utils.ReflectEq *)
Class ReflectEq A := { eqb : A -> A -> bool; ... }.
Infix "==" := eqb (at level 70).

(* From MetaRocq.Common.Kernames — instance for kername *)
Definition eqb kn kn' := match compare kn kn' with Eq => true | _ => false end.
#[global, program] Instance reflect_kername : ReflectEq kername := { eqb := eqb }.

(* Convenience notation (only parsing) *)
Notation eq_kername := (eqb (A:=kername)).
```

**Usage:** `if kn == ind_kn then ... else ...`

**Imports needed:**
```coq
From MetaRocq.Common Require Import Kernames.
(* ReflectEq is re-exported via Kernames, but if not: *)
From MetaRocq.Utils Require Import ReflectEq.
```

## Term Decomposition Helpers (Template/AstUtils.v)

```coq
(* Split tApp into head and args *)
Definition decompose_app (t : term) : term * list term :=
  match t with tApp f l => (f, l) | _ => (t, []) end.

(* Split nested tProd into parallel lists of names and types *)
Fixpoint decompose_prod (t : term) : (list aname) * (list term) * term :=
  match t with
  | tProd n A B => let (nAs, B) := decompose_prod B in
                   let (ns, As) := nAs in (n :: ns, A :: As, B)
  | _ => ([], [], t)
  end.

(* Split nested tProd into a context (handles tLetIn too) *)
Fixpoint decompose_prod_assum (Γ : context) (t : term) : context * term :=
  match t with
  | tProd n A B => decompose_prod_assum (Γ ,, vass n A) B
  | tLetIn na b bty b' => decompose_prod_assum (Γ ,, vdef na b bty) b'
  | _ => (Γ, t)
  end.

(* Split exactly n binders (returns None if not enough) *)
Fixpoint decompose_prod_n_assum (Γ : context) n (t : term)
  : option (context * term) := ...

(* Drop the first n tProd binders — useful for skipping parameters *)
Fixpoint remove_arity (n : nat) (t : term) : term :=
  match n with
  | O => t
  | S n => match t with tProd _ _ B => remove_arity n B | _ => t end
  end.

(* Inspect head of an application-like term *)
Definition destInd (t : term) : option (inductive * Instance.t) :=
  match t with tInd ind u => Some (ind, u) | _ => None end.
```

## Lookup Helpers (Template/AstUtils.v)

```coq
Definition lookup_minductive Σ mind :=
  match lookup_env Σ mind with
  | Some (InductiveDecl decl) => Some decl
  | _ => None
  end.

Definition lookup_inductive Σ ind :=
  match lookup_minductive Σ (inductive_mind ind) with
  | Some mdecl =>
    match nth_error mdecl.(ind_bodies) (inductive_ind ind) with
    | Some idecl => Some (mdecl, idecl)
    | None => None
    end
  | None => None
  end.
```

## Constructor Type Helpers (Template/Typing.v)

```coq
(* Instantiate a cstr_type into a self-contained term.
   cstr_type is defined under ind_bodies context;
   this substitutes the inductive references. *)
Definition type_of_constructor mdecl cdecl (c : inductive * nat) (u : Instance.t) :=
  let mind := inductive_mind (fst c) in
  subst0 (inds mind u mdecl.(ind_bodies)) (subst_instance u cdecl.(cstr_type)).
```

**GOTCHA:** Raw `cstr_type` uses `tRel 0` to refer to the inductive itself (for non-mutual).
After `type_of_constructor`, `tRel 0` refers to the inductive replaced by `tInd`.
For Hallmark translation, use `type_of_constructor` to get self-contained constructor types,
then `remove_arity npars` to skip parameters.

## Other Useful Helpers (Template/Ast.v)

```coq
Definition mkApps (t : term) (us : list term) : term
Definition inds (ind : kername) (u : Instance.t) (l : list one_inductive_body) : list term
```

## Constructor type structure

A constructor like `delegate : forall u d r, manager_of u d -> allowed d r -> allowed u r`
has `cstr_type` equal to (schematically):

```
tProd "u" user
  (tProd "d" user
    (tProd "r" resource
      (tProd "_" (tApp manager_of [tRel 2, tRel 1])
        (tProd "_" (tApp allowed [tRel 2, tRel 1])
          (tApp allowed [tRel 4, tRel 2])))))
```

Note: `cstr_type` is defined in context `ind_bodies` (the mutual block).
So `tRel 0` in `cstr_type` refers to the *last* inductive in the block, not to the first parameter.
For a non-mutual inductive, `tRel 0` in `cstr_type` refers to the inductive itself.

The first `ind_npars` binders in the telescope are *parameters* (shared across all constructors).
