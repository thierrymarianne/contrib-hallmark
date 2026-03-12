(** * Clause — Prolog intermediate representation

    Target-language AST produced by the translation.
    A [clause] is a Horn clause: one head atom plus zero or more
    body atoms. A [prolog_term] is either a de Bruijn variable,
    a nullary atom, or a compound term [f(t1, ..., tn)]. *)

From MetaRocq.Template Require Import All.
From Stdlib Require Import List String.
Import ListNotations.

(** A Prolog term: variable, atom, or compound [f(args...)]. *)
Inductive prolog_term :=
| PVar  : nat -> prolog_term
| PAtom : ident -> prolog_term
| PApp  : ident -> list prolog_term -> prolog_term.

(** A Horn clause [head :- body]. Empty body means a fact.
    [cl_witness_args] carries the Rocq constructor's argument template:
    data variables as [PVar i] and proof slots as [PApp "pf" [PAtom n]]. *)
Record clause := {
  cl_name : ident;
  cl_head : prolog_term;
  cl_body : list prolog_term;
  cl_witness_args : list prolog_term;
}.
