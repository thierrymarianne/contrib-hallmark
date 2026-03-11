From MetaRocq.Template Require Import All.
From Hallmark Require Import Clause Telescope Classify Translate Lookup.
From HallmarkTest Require Import QuoteAllowed.
From Stdlib Require Import List.
Import ListNotations.

Definition allowed_env := fst allowed_program.

Definition allowed_ind :=
  match snd allowed_program with
  | tInd ind _ => ind
  | _ => mkInd (MPfile [], ""%bs) 0
  end.

Definition allowed_mib :=
  match find_inductive allowed_env (inductive_mind allowed_ind) with
  | Some mib => mib
  | None => Build_mutual_inductive_body Finite 0 [] [] Monomorphic_ctx None
  end.

Example allowed_produces_three_clauses :
  Nat.eqb (length (translate_inductive allowed_env allowed_ind allowed_mib)) 3 = true
:= eq_refl.
