(** * Translate — Rocq inductive to Prolog clauses

    Core translation pipeline:
    1. Instantiate raw [cstr_type] with [subst0 (inds ...)] so that
       [tRel] references to the inductive become [tInd] nodes.
    2. Strip parameters with [remove_arity].
    3. Parse the telescope, classify each binding, and emit a clause. *)

From MetaRocq.Template Require Import All.
From Hallmark Require Import Clause Telescope Classify.
From Stdlib Require Import List String.
Import ListNotations.

(** Map a MetaRocq [term] to a [prolog_term].
    Variables become [PVar], constructors/constants/inductives become [PAtom]. *)
Definition term_to_prolog (t : term) : prolog_term :=
  match t with
  | tRel n => PVar n
  | tConstruct (mkInd kn _) idx _ => PAtom (snd kn)
  | tConst kn _ => PAtom (snd kn)
  | tInd (mkInd kn _) _ => PAtom (snd kn)
  | _ => PAtom "?"%bs
  end.

Definition args_to_prolog (args : list term) : list prolog_term :=
  map term_to_prolog args.

(** Build the clause head from the conclusion of the constructor type.
    Returns [None] if the conclusion is not an application of [ind_kn]. *)
Definition extract_conclusion (ind_kn : kername) (ret : term) : option prolog_term :=
  match is_ind_app ind_kn ret with
  | Some args => Some (PApp (snd ind_kn) (args_to_prolog args))
  | None => None
  end.

(** Collect clause body atoms from the classified bindings.
    [BRecursive] and [BExternal] bindings produce atoms;
    [BIndex] and [BErased] are silent. *)
Definition extract_body (ind_kn : kername) (classes : list binding_class)
  : list prolog_term :=
  flat_map (fun bc =>
    match bc with
    | BRecursive args => [PApp (snd ind_kn) (args_to_prolog args)]
    | BExternal head args => [PApp (snd head) (args_to_prolog args)]
    | BIndex | BErased => []
    end
  ) classes.

(** Translate one constructor (already instantiated, parameters stripped). *)
Definition translate_constructor (ind_kn : kername) (name : ident) (ty : term)
  : option clause :=
  let '(bindings, ret) := parse_telescope ty in
  let classes := classify_all ind_kn bindings in
  match extract_conclusion ind_kn ret with
  | Some head =>
    let body := extract_body ind_kn classes in
    Some {| cl_name := name; cl_head := head; cl_body := body |}
  | None => None
  end.

(** Instantiate a raw [cstr_type]: substitute inductive self-references
    via [subst0 (inds ...)], then drop the first [ind_npars] binders. *)
Definition instantiate_cstr (mib : mutual_inductive_body) (ind : inductive)
  (cdecl : constructor_body) : term :=
  let subs := inds (inductive_mind ind) [] (ind_bodies mib) in
  remove_arity (ind_npars mib) (subst0 subs (cstr_type cdecl)).

(** Translate every constructor of an inductive into Prolog clauses.
    Takes the [inductive] (with its real kername from the quoted environment)
    and the [mutual_inductive_body] obtained via [find_inductive]. *)
Definition translate_inductive (ind : inductive) (mib : mutual_inductive_body)
  : list clause :=
  let ind_kn := inductive_mind ind in
  match nth_error (ind_bodies mib) (inductive_ind ind) with
  | Some oib =>
    flat_map (fun cdecl =>
      let ty := instantiate_cstr mib ind cdecl in
      match translate_constructor ind_kn (cstr_name cdecl) ty with
      | Some c => [c]
      | None => []
      end
    ) (ind_ctors oib)
  | None => []
  end.
