(** * Telescope — unfold nested [tProd] binders

    Constructor types in MetaRocq are represented as a chain of
    [tProd] nodes. [parse_telescope] flattens them into a list
    of [(binder_name, domain_type)] pairs and the return type. *)

From MetaRocq.Template Require Import All.
From Stdlib Require Import List.
Import ListNotations.

(** Recursively peel [tProd] binders, returning the accumulated
    bindings and the non-[tProd] conclusion. *)
Fixpoint parse_telescope (t : term) : list (aname * term) * term :=
  match t with
  | tProd na ty body =>
    let '(binds, ret) := parse_telescope body in
    ((na, ty) :: binds, ret)
  | _ => ([], t)
  end.
