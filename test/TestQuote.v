From MetaRocq.Template Require Import All.
From HallmarkTest Require Import QuoteAllowed.

Example quoted_is_ind :
  match snd allowed_program with
  | tInd _ _ => true
  | _ => false
  end = true
:= eq_refl.
