From MetaRocq.Template Require Import All.
From Hallmark Require Import Lookup.
From HallmarkTest Require Import QuoteAllowed.

Example found_allowed :
  match snd allowed_program with
  | tInd ind _ =>
    match find_inductive (fst allowed_program) (inductive_mind ind) with
    | Some mib => Nat.eqb (length (ind_bodies mib)) 1
    | None => false
    end
  | _ => false
  end = true
:= eq_refl.
