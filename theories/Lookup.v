From MetaRocq.Template Require Import All.

Definition find_inductive (Σ : global_env) (kn : kername)
  : option mutual_inductive_body :=
  match lookup_env Σ kn with
  | Some (InductiveDecl mib) => Some mib
  | _ => None
  end.
