(** * Translate — Rocq inductive to Prolog clauses

    Core translation pipeline:
    1. Instantiate raw [cstr_type] with [subst0 (inds ...)] so that
       [tRel] references to the inductive become [tInd] nodes.
    2. Strip parameters with [remove_arity].
    3. Parse the telescope, classify each binding, and emit a clause.

    De Bruijn indices are normalized to canonical telescope positions:
    [tRel n] at depth [d] refers to binding [d - 1 - n]. *)

From MetaRocq.Template Require Import All.
From Hallmark Require Import Clause Telescope Classify Lookup.
From Stdlib Require Import List.
Import ListNotations.

(** Map a MetaRocq [term] to a [prolog_term].
    [depth] is the number of enclosing binders; [tRel n] is
    normalized to canonical binding position [depth - 1 - n]. *)
Definition term_to_prolog (Σ : global_env) (depth : nat) (t : term)
  : prolog_term :=
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
    Each binding at index [i] has its args at depth [i]. *)
Definition extract_body (Σ : global_env) (ind_kn : kername)
  (classes : list binding_class) : list prolog_term :=
  let fix go (i : nat) (cs : list binding_class) : list prolog_term :=
    match cs with
    | [] => []
    | bc :: rest =>
      (match bc with
       | BRecursive args => [PApp (snd ind_kn) (args_to_prolog Σ i args)]
       | BExternal head args => [PApp (snd head) (args_to_prolog Σ i args)]
       | BIndex | BErased => []
       end) ++ go (S i) rest
    end
  in go 0 classes.

(** Translate one constructor (already instantiated, parameters stripped). *)
Definition translate_constructor (Σ : global_env) (ind_kn : kername)
  (name : ident) (ty : term) : option clause :=
  let '(bindings, ret) := parse_telescope ty in
  let total := length bindings in
  let classes := classify_all ind_kn bindings in
  match extract_conclusion Σ ind_kn total ret with
  | Some head =>
    let body := extract_body Σ ind_kn classes in
    Some {| cl_name := name; cl_head := head; cl_body := body |}
  | None => None
  end.

(** Instantiate a raw [cstr_type]: substitute inductive self-references
    via [subst0 (inds ...)], then drop the first [ind_npars] binders. *)
Definition instantiate_cstr (mib : mutual_inductive_body) (ind : inductive)
  (cdecl : constructor_body) : term :=
  let subs := inds (inductive_mind ind) [] (ind_bodies mib) in
  remove_arity (ind_npars mib) (subst0 subs (cstr_type cdecl)).

(** Translate every constructor of an inductive into Prolog clauses. *)
Definition translate_inductive (Σ : global_env) (ind : inductive)
  (mib : mutual_inductive_body) : list clause :=
  let ind_kn := inductive_mind ind in
  match nth_error (ind_bodies mib) (inductive_ind ind) with
  | Some oib =>
    flat_map (fun cdecl =>
      let ty := instantiate_cstr mib ind cdecl in
      match translate_constructor Σ ind_kn (cstr_name cdecl) ty with
      | Some c => [c]
      | None => []
      end
    ) (ind_ctors oib)
  | None => []
  end.
