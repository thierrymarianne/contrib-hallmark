From MetaRocq.Template Require Import All.
From Hallmark Require Import Clause Telescope Classify Translate Lookup.
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

Example allowed_produces_three_clauses :
  Nat.eqb (length (translate_inductive allowed_ind allowed_mib)) 3 = true
:= eq_refl.
