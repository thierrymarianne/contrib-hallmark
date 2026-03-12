From MetaRocq.Template Require Import All.
From Hallmark Require Import Clause.

Definition admin_all_clause :=
  {| cl_name := "admin_all"%bs;
     cl_head := PApp "allowed"%bs [PAtom "admin"%bs; PVar 0];
     cl_body := [];
     cl_witness_args := [PVar 0] |}.

Example admin_clause_name :
  cl_name admin_all_clause = "admin_all"%bs := eq_refl.
