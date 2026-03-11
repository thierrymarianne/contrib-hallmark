From MetaRocq.Template Require Import All.
From Hallmark Require Import Lookup Inspect.
From HallmarkTest Require Import QuoteAllowed.

Example three_constructors :
  match snd allowed_program with
  | tInd ind _ =>
    match find_inductive (fst allowed_program) (inductive_mind ind) with
    | Some mib => Nat.eqb (length (get_constructors mib)) 3
    | None => false
    end
  | _ => false
  end = true
:= eq_refl.
