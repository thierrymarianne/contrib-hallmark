(** * Inspect — extract constructor names and raw types

    Retrieves the [(ident * term)] pairs from the first body of a
    mutual inductive block. The returned [term] values are raw
    [cstr_type] fields — they still contain [tRel] references to the
    inductive itself and must be instantiated with [subst0 (inds ...)]
    before further processing. *)

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
