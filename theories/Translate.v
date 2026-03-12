(** * Translate — Rocq inductive to Prolog clauses

    Core translation pipeline:
    1. Instantiate raw [cstr_type] with [subst0 (inds ...)] so that
       [tRel] references to the inductive become [tInd] nodes.
    2. Strip parameters with [remove_arity].
    3. Parse the telescope, classify each binding, and emit a clause.

    De Bruijn indices are normalized to canonical telescope positions:
    [tRel n] at depth [d] refers to binding [d - 1 - n]. *)

From MetaRocq.Template Require Import All.
From MetaRocq.Utils Require Import bytestring MRString.
From Hallmark Require Import Clause Telescope Classify Lookup Clp.
From Stdlib Require Import List.
Import ListNotations.

(** Check whether a kername refers to [nat] by its short name. *)
Definition is_nat_kn (kn : kername) : bool :=
  String.eqb (snd kn) "nat"%bs.

(** Try to read a Peano nat literal from the MetaRocq AST.
    [O] is [tConstruct nat 0], [S n] is [tApp (tConstruct nat 1) [n]].
    Only matches constructors of the [nat] inductive. *)
Fixpoint read_nat (fuel : nat) (t : term) : option nat :=
  match fuel with
  | 0 => None
  | S fuel' =>
    match t with
    | tConstruct (mkInd kn 0) 0 _ =>
      if is_nat_kn kn then Some 0 else None
    | tApp (tConstruct (mkInd kn 0) 1 _) [x] =>
      if is_nat_kn kn then
        match read_nat fuel' x with
        | Some n => Some (S n)
        | None   => None
        end
      else None
    | _ => None
    end
  end.

(** Map a MetaRocq [term] to a [prolog_term].
    [depth] is the number of enclosing binders; [tRel n] is
    normalized to canonical binding position [depth - 1 - n].
    Peano nat literals are converted to integer atoms. *)
Definition term_to_prolog (Σ : global_env) (depth : nat) (t : term)
  : prolog_term :=
  match read_nat 1000 t with
  | Some n => PAtom (string_of_nat n)
  | None =>
    match t with
    | tRel n => PVar (depth - 1 - n)
    | tConstruct ind idx _ =>
      match lookup_constructor_name Σ ind idx with
      | Some name => PAtom name
      | None => PAtom "?"%bs
      end
    | tConst kn _ => PAtom (snd kn)
    | tInd (mkInd kn _) _ => PAtom (snd kn)
    | _ => PAtom "?"%bs
    end
  end.

Definition args_to_prolog (Σ : global_env) (depth : nat) (args : list term)
  : list prolog_term :=
  map (term_to_prolog Σ depth) args.

(** Build the clause head from the conclusion.
    [total] is the total number of bindings in the telescope. *)
Definition extract_conclusion (Σ : global_env) (ind_kn : kername)
  (total : nat) (ret : term) : option prolog_term :=
  match is_ind_app ind_kn ret with
  | Some args => Some (PApp (snd ind_kn) (args_to_prolog Σ total args))
  | None => None
  end.

(** Collect clause body atoms from classified bindings.
    Each binding at index [i] has its args at depth [i].
    [BConstraint] bindings become [PConstraint op lhs rhs]. *)
Definition extract_body (Σ : global_env) (ind_kn : kername)
  (classes : list binding_class) : list prolog_term :=
  let fix go (i : nat) (cs : list binding_class) : list prolog_term :=
    match cs with
    | [] => []
    | bc :: rest =>
      (match bc with
       | BRecursive args => [PApp (snd ind_kn) (args_to_prolog Σ i args)]
       | BExternal head args => [PApp (snd head) (args_to_prolog Σ i args)]
       | BConstraint op args =>
         match args with
         | [a1; a2] =>
           [PConstraint op (term_to_prolog Σ i a1) (term_to_prolog Σ i a2)]
         | [_; a1; a2] =>
           [PConstraint op (term_to_prolog Σ i a1) (term_to_prolog Σ i a2)]
         | _ => []
         end
       | BIndex | BErased => []
       end) ++ go (S i) rest
    end
  in go 0 classes.

(** Build the Rocq constructor argument template from classified bindings.
    [BIndex] at position [i] becomes [PVar i] (a data variable).
    [BRecursive]/[BExternal] becomes [PApp "pf" [PAtom j]] (proof slot).
    [BErased] bindings are dropped. *)
Fixpoint build_witness_args_aux (cs : list binding_class) (i body_idx : nat)
  : list prolog_term :=
  match cs with
  | [] => []
  | bc :: rest =>
    match bc with
    | BIndex => PVar i :: build_witness_args_aux rest (S i) body_idx
    | BRecursive _ | BExternal _ _ =>
      PApp "pf"%bs [PAtom (string_of_nat body_idx)]
        :: build_witness_args_aux rest (S i) (S body_idx)
    | BConstraint _ _ =>
      PAtom "lia"%bs :: build_witness_args_aux rest (S i) (S body_idx)
    | BErased => build_witness_args_aux rest (S i) body_idx
    end
  end.

Definition build_witness_args (classes : list binding_class) : list prolog_term :=
  build_witness_args_aux classes 0 0.

(** Translate one constructor (already instantiated, parameters stripped).
    For nullary constructors (empty telescope, no conclusion args),
    the constructor name is injected as an atom argument in the head:
    e.g. [admin : user] becomes [user(admin).] *)
Definition translate_constructor (tbl : clp_table) (Σ : global_env)
  (ind_kn : kername) (name : ident) (ty : term) : option clause :=
  let '(bindings, ret) := parse_telescope ty in
  let total := length bindings in
  let classes := classify_all tbl ind_kn bindings in
  match extract_conclusion Σ ind_kn total ret with
  | Some head =>
    let head' :=
      match head with
      | PApp f [] => PApp f [PAtom name]
      | _ => head
      end in
    let body := extract_body Σ ind_kn classes in
    let wargs := build_witness_args classes in
    Some {| cl_name := name; cl_head := head'; cl_body := body;
            cl_witness_args := wargs |}
  | None => None
  end.

(** Instantiate a raw [cstr_type]: substitute inductive self-references
    via [subst0 (inds ...)], then drop the first [ind_npars] binders. *)
Definition instantiate_cstr (mib : mutual_inductive_body) (ind : inductive)
  (cdecl : constructor_body) : term :=
  let subs := inds (inductive_mind ind) [] (ind_bodies mib) in
  remove_arity (ind_npars mib) (subst0 subs (cstr_type cdecl)).

(** Translate every constructor of an inductive into Prolog clauses. *)
Definition translate_inductive (tbl : clp_table) (Σ : global_env)
  (ind : inductive) (mib : mutual_inductive_body) : list clause :=
  let ind_kn := inductive_mind ind in
  match nth_error (ind_bodies mib) (inductive_ind ind) with
  | Some oib =>
    flat_map (fun cdecl =>
      let ty := instantiate_cstr mib ind cdecl in
      match translate_constructor tbl Σ ind_kn (cstr_name cdecl) ty with
      | Some c => [c]
      | None => []
      end
    ) (ind_ctors oib)
  | None => []
  end.
