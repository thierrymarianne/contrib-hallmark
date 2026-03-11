# MetaRocq Term AST

Source: Sozeau et al., "The MetaCoq Project", Journal of Automated Reasoning, 2020.
https://inria.hal.science/hal-02167423v1/file/The_MetaCoq_Project.pdf

## Term constructors

```coq
Inductive term : Set :=
  | tRel (n : nat)
  | tVar (id : ident)
  | tEvar (ev : nat) (args : list term)
  | tSort (s : universe)
  | tCast (t : term) (kind : cast_kind) (v : term)
  | tProd (na : name) (ty : term) (body : term)
  | tLambda (na : name) (ty : term) (body : term)
  | tLetIn (na : name) (def : term) (def_ty : term) (body : term)
  | tApp (f : term) (args : list term)
  | tConst (c : kername) (u : universe_instance)
  | tInd (ind : inductive) (u : universe_instance)
  | tConstruct (ind : inductive) (idx : nat) (u : universe_instance)
  | tCase (ind_and_nbparams : inductive * nat) (type_info : term)
          (discr : term) (branches : list (nat * term))
  | tProj (proj : projection) (t : term)
  | tFix (mfix : mfixpoint term) (idx : nat)
  | tCoFix (mfix : mfixpoint term) (idx : nat).
```

## Constructor details

- **tRel n**: de Bruijn index. Variable bound by tLambda, tProd, or tLetIn.
- **tVar id**: named variable (sections, interactive proofs). Rarely used in quoted terms.
- **tEvar ev args**: existential variable (hole). Not relevant for Hallmark.
- **tSort s**: universe sort. s is Prop, Set, or a Type universe expression.
- **tCast t k v**: type cast `(t : v)`. Absent from PCUIC representation.
- **tProd na ty body**: dependent product `forall (na : ty), body`. The core of constructor types.
- **tLambda na ty body**: lambda `fun (na : ty) => body`.
- **tLetIn na def def_ty body**: local let `let na : def_ty := def in body`.
- **tApp f args**: n-ary application. f must not be an application; args must be non-empty.
- **tConst c u**: reference to a global constant (Definition, Lemma, Axiom). c is a kername (fully qualified). u is universe instance.
- **tInd ind u**: reference to an inductive type. ind = (kername, index_in_mutual_block).
- **tConstruct ind idx u**: reference to a constructor. ind identifies the inductive; idx is the constructor index (0-based).
- **tCase (ind, npar) p c brs**: pattern matching. ind = inductive, npar = number of parameters, p = return type predicate, c = scrutinee, brs = list of (nargs, branch_term).
- **tProj proj t**: primitive record projection applied to t.
- **tFix mfix idx**: fixpoint. mfix is a list of mutual fixpoint bodies; idx selects which one.
- **tCoFix mfix idx**: cofixpoint (same structure as tFix).

## Fixpoint body record

```coq
Record def term := mkdef {
  dname : name;
  dtype : term;    (* type of the fixpoint *)
  dbody : term;    (* body (with lambdas for arguments) *)
  rarg  : nat;     (* index of the structurally decreasing argument *)
}.
Definition mfixpoint term := list (def term).
```

## Global declarations

```coq
Inductive global_decl :=
  | ConstantDecl : kername -> constant_body -> global_decl
  | InductiveDecl : kername -> mutual_inductive_body -> global_decl.
```

### constant_body

```coq
Record constant_body := {
  cst_type : term;
  cst_body : option term;   (* None = axiom, Some = definition *)
  cst_universes : universe_context;
}.
```

### mutual_inductive_body

Contains:
- `ind_npars : nat` — number of parameters
- `ind_bodies : list one_inductive_body` — list of inductive types in the mutual block
- `ind_universes : universe_context`

### one_inductive_body

Contains:
- `ind_name : ident`
- `ind_type : term` — the full type of the inductive (e.g. `nat -> Prop`)
- `ind_kelim : list sort_family` — allowed elimination sorts
- `ind_ctors : list (ident * term * nat)` — constructors: (name, type, arity)
- `ind_projs : list (ident * term)` — projections (for records)

## Name types

```coq
Definition ident := string.
Inductive name := nAnon | nNamed (_ : ident).
```

## inductive type

```coq
Record inductive := {
  inductive_mind : kername;   (* name of the mutual block *)
  inductive_ind : nat;        (* index within the block *)
}.
```
