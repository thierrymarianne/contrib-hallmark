From MetaRocq.Template Require Import All.
From Hallmark Require Import Telescope Lookup.
From HallmarkExamples Require Import QuoteAllowed.
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

Definition delegate_type :=
  let subs := inds (inductive_mind allowed_ind) [] (ind_bodies allowed_mib) in
  match ind_bodies allowed_mib with
  | oib :: _ =>
    match nth_error (ind_ctors oib) 2 with
    | Some cb => subst0 subs (cstr_type cb)
    | None => tVar "missing"%bs
    end
  | [] => tVar "missing"%bs
  end.

Example delegate_telescope_length :
  let '(binds, _) := parse_telescope delegate_type in
  Nat.eqb (length binds) 5 = true
:= eq_refl.

Example delegate_return_type_is_app :
  let '(_, ret) := parse_telescope delegate_type in
  match ret with tApp _ _ => true | _ => false end = true
:= eq_refl.
