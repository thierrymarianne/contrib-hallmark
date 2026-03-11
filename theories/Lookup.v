(** * Lookup — resolve a kername to its mutual_inductive_body

    Given a [global_env] obtained from [tmQuoteRec] and a [kername],
    return the [mutual_inductive_body] if the name refers to an
    inductive declaration. *)

From MetaRocq.Template Require Import All.

Definition find_inductive (Σ : global_env) (kn : kername)
  : option mutual_inductive_body :=
  match lookup_env Σ kn with
  | Some (InductiveDecl mib) => Some mib
  | _ => None
  end.
