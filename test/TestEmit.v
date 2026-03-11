From MetaRocq.Template Require Import All.
From MetaRocq.Utils Require Import bytestring MRString.
From Hallmark Require Import Clause Emit.
From Stdlib Require Import List.
Import ListNotations.

Local Open Scope bs_scope.

Example print_compound :
  print_term (PApp "allowed" [PAtom "admin"; PVar 0])
  = "allowed(admin, X0)"
:= eq_refl.

Example print_atom :
  print_term (PAtom "admin") = "admin"
:= eq_refl.

Example print_var :
  print_term (PVar 3) = "X3"
:= eq_refl.

Definition admin_all_clause :=
  {| cl_name := "admin_all";
     cl_head := PApp "allowed" [PAtom "admin"; PVar 0];
     cl_body := [] |}.

Definition delegate_clause :=
  {| cl_name := "delegate";
     cl_head := PApp "allowed" [PVar 0; PVar 2];
     cl_body := [PApp "manager_of" [PVar 0; PVar 1];
                 PApp "allowed" [PVar 1; PVar 2]] |}.

Example print_admin_fact :
  print_clause admin_all_clause =
  "allowed(admin, X0) :- rule(admin_all)."
:= eq_refl.

Example print_delegate_clause :
  print_clause delegate_clause =
  "allowed(X0, X2) :- rule(delegate), manager_of(X0, X1), allowed(X1, X2)."
:= eq_refl.

Example program_starts_with_rule :
  is_prefix "rule(_)." (print_program [admin_all_clause]) = true
:= eq_refl.

Example program_has_clause :
  is_substring "admin_all" (print_program [admin_all_clause]) = true
:= eq_refl.
