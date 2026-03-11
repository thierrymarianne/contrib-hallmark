(** * Lookup — resolve a kername to its mutual_inductive_body

    Given a [global_env] obtained from [tmQuoteRec] and a [kername],
    return the [mutual_inductive_body] if the name refers to an
    inductive declaration. *)

From MetaRocq.Template Require Import All.
From Stdlib Require Import List.
Import ListNotations.

Definition find_inductive (Σ : global_env) (kn : kername)
  : option mutual_inductive_body :=
  match lookup_env Σ kn with
  | Some (InductiveDecl mib) => Some mib
  | _ => None
  end.

(** Look up a constructor's name from the global environment. *)
Definition lookup_constructor_name (Σ : global_env) (ind : inductive) (cidx : nat)
  : option ident :=
  match lookup_env Σ (inductive_mind ind) with
  | Some (InductiveDecl mib) =>
    match nth_error (ind_bodies mib) (inductive_ind ind) with
    | Some oib =>
      match nth_error (ind_ctors oib) cidx with
      | Some cdecl => Some (cstr_name cdecl)
      | None => None
      end
    | None => None
    end
  | _ => None
  end.
