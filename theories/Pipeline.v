(** * Pipeline — TemplateMonad entry point

    Translates all inductive types and simple structural Fixpoints
    in a Rocq module to Prolog.
    Call with [MetaRocq Run (hallmark_module "MyLib.MyModule"%bs).]
    to get the Prolog program as a string. *)

From MetaRocq.Template Require Import All.
From MetaRocq.Utils Require Import bytestring MRString.
From MetaRocq.Common Require Import Kernames Environment.
From Hallmark Require Import Lookup Translate TranslateFixpoint Emit Clause Clp.
From Stdlib Require Import List.
Import ListNotations.

Local Open Scope bs_scope.

Definition filter_ind_refs (refs : list global_reference) : list inductive :=
  flat_map (fun gr =>
    match gr with
    | IndRef ind => [ind]
    | _ => []
    end) refs.

Definition filter_const_refs (refs : list global_reference) : list kername :=
  flat_map (fun gr =>
    match gr with
    | ConstRef kn => [kn]
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

(** Monadic loop: quote each constant kername. *)
Fixpoint quote_constants (kns : list kername)
  : TemplateMonad (list (kername * constant_body)) :=
  match kns with
  | [] => tmReturn []
  | kn :: rest =>
    tmBind (tmQuoteConstant kn false) (fun cb =>
      tmBind (quote_constants rest) (fun acc =>
        tmReturn ((kn, cb) :: acc)))
  end.

(** Count leading [tLambda] binders, returning the count and inner term. *)
Fixpoint count_lambdas (n : nat) (t : term) : nat * term :=
  match t with
  | tLambda _ _ body => count_lambdas (S n) body
  | _ => (n, t)
  end.

(** Check whether a constant body is a trusted predicate
    ([Definition p x y ... : Prop := True]).
    Returns [Some arity] if so. *)
Definition is_trusted_def (true_kn : kername) (cb : constant_body)
  : option nat :=
  match cst_body cb with
  | Some body =>
    let '(arity, core) := count_lambdas 0 body in
    match core with
    | tInd (mkInd kn 0) _ =>
      if kn == true_kn then Some arity else None
    | _ => None
    end
  | None => None
  end.

(** Collect trusted predicate declarations (name + arity) from constants. *)
Definition collect_trusted (true_kn : kername)
  (consts : list (kername * constant_body)) : list (ident * nat) :=
  flat_map (fun '(kn, cb) =>
    match is_trusted_def true_kn cb with
    | Some arity => [(snd kn, arity)]
    | None => []
    end) consts.

(** Extract a kername from a quoted inductive term. *)
Definition extract_ind_kn (t : term) : kername :=
  match t with
  | tInd (mkInd kn _) _ => kn
  | _ => (MPfile [], ""%bs)
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

(** Analyze constants into fixpoints and trusted predicates. *)
Definition collect_fixpoints (consts : list (kername * constant_body))
  : list fixpoint_info :=
  flat_map (fun '(kn, cb) =>
    match analyze_fixpoint kn cb with
    | Some fi => [fi]
    | None => []
    end) consts.

(** Collect extra inductives needed by Fixpoint [tCase] discriminees. *)
Definition fixpoint_dep_inds (fis : list fixpoint_info) : list kername :=
  map (fun fi => inductive_mind (ci_ind (fix_ci fi))) fis.

(** Dedup a list of kernames. *)
Definition dedup_kns (kns : list kername) : list kername :=
  let fix go (seen acc : list kername) (l : list kername) :=
    match l with
    | [] => List.rev acc
    | kn :: rest =>
      if existsb (fun s => kn == s) seen
      then go seen acc rest
      else go (kn :: seen) (kn :: acc) rest
    end
  in go [] [] kns.

(** Translate all Fixpoints into Prolog clauses. *)
Definition translate_all_fixpoints (tbl : clp_table) (Σ : global_env)
  (true_kn false_kn : kername) (fis : list fixpoint_info) : list clause :=
  flat_map (translate_fixpoint tbl Σ true_kn false_kn) fis.

(** Translate every inductive and Fixpoint in a module to a Prolog program,
    including trusted predicate declarations for [Definition ... := True]. *)
Definition hallmark_module (mod_name : qualid) : TemplateMonad string :=
  tmBind clpfd_defaults (fun tbl =>
  tmBind (tmQuote True) (fun true_tm =>
  tmBind (tmQuote False) (fun false_tm =>
  tmBind (tmQuoteModule mod_name) (fun refs =>
    let true_kn := extract_ind_kn true_tm in
    let false_kn := extract_ind_kn false_tm in
    let inds := filter_ind_refs refs in
    let const_kns := filter_const_refs refs in
    tmBind (quote_constants const_kns) (fun consts =>
      let trusted := collect_trusted true_kn consts in
      let fixpoints := collect_fixpoints consts in
      let fix_dep_kns := fixpoint_dep_inds fixpoints in
      let ind_kns := collect_kernames inds in
      let all_kns := dedup_kns (List.app ind_kns fix_dep_kns) in
      tmBind (quote_all all_kns) (fun decls =>
        let Σ := build_env decls in
        let ind_clauses := translate_all tbl Σ inds in
        let fix_clauses :=
          translate_all_fixpoints tbl Σ true_kn false_kn fixpoints in
        let all_clauses := List.app ind_clauses fix_clauses in
        match all_clauses, trusted with
        | [], [] =>
          tmFail "No inductives, fixpoints, or trusted predicates found in module"%bs
        | _, _ => tmReturn (print_program trusted all_clauses)
        end)))))).
