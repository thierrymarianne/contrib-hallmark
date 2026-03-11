From MetaRocq.Template Require Import All.
From Stdlib Require Import List.
Import ListNotations.

Definition get_constructors (mib : mutual_inductive_body)
  : list (ident * term) :=
  match ind_bodies mib with
  | oib :: _ =>
    map (fun cb => (cstr_name cb, cstr_type cb)) (ind_ctors oib)
  | [] => []
  end.
