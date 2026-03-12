(** * Pipeline — TemplateMonad entry point

    Translates all inductive types in a Rocq module to Prolog.
    Call with [MetaRocq Run (hallmark_module "MyLib.MyModule"%bs).]
    to get the Prolog program as a string. *)

From MetaRocq.Template Require Import All.
From MetaRocq.Utils Require Import bytestring MRString.
From MetaRocq.Common Require Import Kernames Environment.
From Hallmark Require Import Lookup Translate Emit Clause Clp.
From Stdlib Require Import List.
Import ListNotations.

Local Open Scope bs_scope.

Definition filter_ind_refs (refs : list global_reference) : list inductive :=
  flat_map (fun gr =>
    match gr with
    | IndRef ind => [ind]
    | _ => []
    end) refs.

(** Unique kername extraction (dedup by kername equality). *)
Definition collect_kernames (inds : list inductive) : list kername :=
  let fix go (seen acc : list kername) (l : list inductive) :=
    match l with
    | [] => List.rev acc
    | ind :: rest =>
      let kn := inductive_mind ind in
      if existsb (fun s => kn == s) seen
      then go seen acc rest
      else go (kn :: seen) (kn :: acc) rest
    end
  in go [] [] inds.

(** Monadic loop: quote each kername into a global_declarations list. *)
Fixpoint quote_all (kns : list kername)
  : TemplateMonad global_declarations :=
  match kns with
  | [] => tmReturn []
  | kn :: rest =>
    tmBind (tmQuoteInductive kn) (fun mib =>
      tmBind (quote_all rest) (fun acc =>
        tmReturn ((kn, InductiveDecl mib) :: acc)))
  end.

Definition build_env (decls : global_declarations) : global_env :=
  {| universes := ContextSet.empty;
     declarations := decls;
     retroknowledge := Retroknowledge.empty |}.

Definition translate_all (tbl : clp_table) (Σ : global_env)
  (inds : list inductive) : list clause :=
  flat_map (fun ind =>
    match find_inductive Σ (inductive_mind ind) with
    | Some mib => translate_inductive tbl Σ ind mib
    | None => []
    end) inds.

(** Translate every inductive in a module to a Prolog program. *)
Definition hallmark_module (mod_name : qualid) : TemplateMonad string :=
  tmBind clpfd_defaults (fun tbl =>
  tmBind (tmQuoteModule mod_name) (fun refs =>
    let inds := filter_ind_refs refs in
    match inds with
    | [] => tmFail "No inductives found in module"%bs
    | _ =>
      let kns := collect_kernames inds in
      tmBind (quote_all kns) (fun decls =>
        let Σ := build_env decls in
        let all_clauses := translate_all tbl Σ inds in
        tmReturn (print_program all_clauses))
    end)).
