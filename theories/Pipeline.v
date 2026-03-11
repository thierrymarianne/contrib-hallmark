(** * Pipeline — TemplateMonad entry point

    Ties quoting, translation, and emission into a single monadic
    action. Call with [MetaRocq Run (hallmark_pipeline my_inductive).]
    to emit the Prolog program to Rocq's feedback channel. *)

From MetaRocq.Template Require Import All.
From MetaRocq.Utils Require Import bytestring MRString.
From Hallmark Require Import Lookup Translate Emit Clause.
From Stdlib Require Import List.
Import ListNotations.

Local Open Scope bs_scope.

(** Full pipeline: quote an inductive, translate to clauses, emit Prolog. *)
Definition hallmark_pipeline {A : Type} (a : A) : TemplateMonad string :=
  tmBind (tmQuoteRec a) (fun prog =>
    let '(Σ, t) := prog in
    match t with
    | tInd ind _ =>
      match find_inductive Σ (inductive_mind ind) with
      | Some mib =>
        let clauses := translate_inductive Σ ind mib in
        let prolog := print_program clauses in
        let marked := "%%HALLMARK_BEGIN%%" ++ nl ++ prolog ++ "%%HALLMARK_END%%" in
        tmBind (tmMsg marked) (fun _ => tmReturn prolog)
      | None => tmFail "Inductive not found"%bs
      end
    | _ => tmFail "Not an inductive type"%bs
    end).
