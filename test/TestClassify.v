From MetaRocq.Template Require Import All.
From MetaRocq.Common Require Import Kernames.
From Hallmark Require Import Telescope Classify Lookup.
From HallmarkTest Require Import QuoteAllowed.
From Stdlib Require Import List.
Import ListNotations.

Definition allowed_ind :=
  match snd allowed_program with
  | tInd ind _ => ind
  | _ => mkInd (MPfile [], ""%bs) 0
  end.

Definition allowed_mib :=
  match find_inductive (fst allowed_program) (inductive_mind allowed_ind) with
  | Some mib => mib
  | None => Build_mutual_inductive_body Finite 0 [] [] Monomorphic_ctx None
  end.

Definition allowed_ind_kn := inductive_mind allowed_ind.

Definition delegate_bindings :=
  let subs := inds (inductive_mind allowed_ind) [] (ind_bodies allowed_mib) in
  match ind_bodies allowed_mib with
  | oib :: _ =>
    match nth_error (ind_ctors oib) 2 with
    | Some cb =>
      let ty := subst0 subs (cstr_type cb) in
      let '(binds, _) := parse_telescope ty in
      binds
    | None => []
    end
  | [] => []
  end.

Example delegate_has_recursive :
  existsb (fun c => match c with BRecursive _ => true | _ => false end)
    (classify_all allowed_ind_kn delegate_bindings) = true
:= eq_refl.

Example delegate_has_external :
  existsb (fun c => match c with BExternal _ _ => true | _ => false end)
    (classify_all allowed_ind_kn delegate_bindings) = true
:= eq_refl.
