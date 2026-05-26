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

(** Collect inductive kernames referenced anywhere in a term.

    Used to compute the transitive closure of inductives that need to
    be quoted into the global environment so that
    [lookup_constructor_name] can resolve enum constructors used in
    constructor premises. Without this, references to e.g.
    [ch_succeeded] from [chain_ok]'s premise render as [?] when
    [charge_state] is declared in a different module than the target.

    [fuel] bounds the recursion depth — 1000 is generous given that
    constructor types are usually small. *)
Fixpoint collect_kn_refs (fuel : nat) (t : term) : list kername :=
  match fuel with
  | 0 => []
  | S fuel' =>
    match t with
    | tInd (mkInd kn _) _ => [kn]
    | tConstruct (mkInd kn _) _ _ => [kn]
    | tApp f args =>
      List.app
        (collect_kn_refs fuel' f)
        (flat_map (collect_kn_refs fuel') args)
    | tProd _ ty body =>
      List.app (collect_kn_refs fuel' ty) (collect_kn_refs fuel' body)
    | tLambda _ ty body =>
      List.app (collect_kn_refs fuel' ty) (collect_kn_refs fuel' body)
    | tLetIn _ a b body =>
      List.app (collect_kn_refs fuel' a)
        (List.app (collect_kn_refs fuel' b) (collect_kn_refs fuel' body))
    | tCase _ _ scrut branches =>
      List.app
        (collect_kn_refs fuel' scrut)
        (flat_map (fun b => collect_kn_refs fuel' (bbody b)) branches)
    | _ => []
    end
  end.

(** Collect inductive kernames referenced in all constructor types of a
    mutual_inductive_body, plus any indices used in the inductive's
    return type. *)
Definition mib_kn_refs (mib : mutual_inductive_body) : list kername :=
  flat_map (fun oib =>
    flat_map (fun cb => collect_kn_refs 1000 (cstr_type cb))
             (ind_ctors oib))
    (ind_bodies mib).

(** Check whether a kername belongs to a "skip" module path — these
    inductives are not quoted into the engine even when referenced.

    Pulling in [Corelib.Init.Datatypes.nat], [Corelib.Init.Peano.le],
    etc., produces extra clauses whose constructor names ([S], [O],
    [le_S]) start uppercase, which Prolog parses as variables and
    rejects in head position. These inductives are not used at query
    time — concrete numbers come from snapshot facts, not Peano nat
    structure — so dropping them is safe and the engine becomes
    consult-clean.

    Match on the LAST element of the module path (MetaRocq stores
    paths innermost-first, so the root namespace [Corelib] / [Stdlib]
    is the last element). *)
Fixpoint last_path_elt (path : list ident) : option ident :=
  match path with
  | [] => None
  | [x] => Some x
  | _ :: rest => last_path_elt rest
  end.

Definition is_skip_kn (kn : kername) : bool :=
  match fst kn with
  | MPfile path =>
    match last_path_elt path with
    | Some root =>
      String.eqb root "Stdlib"%bs || String.eqb root "Corelib"%bs
    | None => false
    end
  | _ => false
  end.

(** Transitive closure: starting from a seed list of inductive
    kernames, repeatedly quote and scan each one's constructor types
    for additional inductive references, quoting those too, until no
    new kernames appear.

    Returns the full [global_declarations] list (deduplicated).

    [fuel] bounds the total number of iterations — set generously
    because each iteration adds at least one new kername.

    This closes §2 of the hallmark upstream requirements (the
    single-module quote scope issue): user theories can split
    inductives across multiple .v files, and hallmark will quote the
    transitive closure starting from the inductives declared in the
    target module. *)
Fixpoint close_kns (fuel : nat) (seen : list kername) (todo : list kername)
  : TemplateMonad global_declarations :=
  match fuel with
  | 0 => tmReturn []
  | S fuel' =>
    match todo with
    | [] => tmReturn []
    | kn :: rest =>
      if existsb (fun s => kn == s) seen
      then close_kns fuel' seen rest
      else if is_skip_kn kn
      then close_kns fuel' (kn :: seen) rest
      else
        tmBind (tmQuoteInductive kn) (fun mib =>
          let new_refs := mib_kn_refs mib in
          let new_unseen := List.filter
            (fun k => negb (existsb (fun s => k == s) (kn :: seen)))
            new_refs in
          tmBind (close_kns fuel' (kn :: seen)
                    (List.app new_unseen rest)) (fun rest_decls =>
            tmReturn ((kn, InductiveDecl mib) :: rest_decls)))
    end
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

Definition translate_all (tbl : clp_table) (arith : arith_table)
  (Σ : global_env) (inds : list inductive) : list clause :=
  flat_map (fun ind =>
    match find_inductive Σ (inductive_mind ind) with
    | Some mib => translate_inductive tbl arith Σ ind mib
    | None => []
    end) inds.

(** Recover the [list inductive] from a global_declarations list,
    expanding each mutual_inductive_body into one [inductive] per
    body index. Used after [close_kns] to extend the translation
    target set with transitively-discovered inductives. *)
Definition inds_of_decls (decls : global_declarations) : list inductive :=
  flat_map (fun '(kn, decl) =>
    match decl with
    | InductiveDecl mib =>
      let n := length (ind_bodies mib) in
      let fix mkrange (i : nat) (acc : list inductive) : list inductive :=
        match i with
        | 0 => acc
        | S i' => mkrange i' ({| inductive_mind := kn; inductive_ind := i' |} :: acc)
        end
      in mkrange n []
    | _ => []
    end) decls.

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
Definition translate_all_fixpoints (tbl : clp_table) (arith : arith_table)
  (Σ : global_env) (true_kn false_kn : kername) (fis : list fixpoint_info)
  : list clause :=
  flat_map (translate_fixpoint tbl arith Σ true_kn false_kn) fis.

(** Translate every inductive and Fixpoint in a module to a Prolog program,
    including trusted predicate declarations for [Definition ... := True]. *)
(** Aggregate refs from a list of modules via tmQuoteModule. *)
Fixpoint quote_module_refs (mod_names : list qualid)
  : TemplateMonad (list global_reference) :=
  match mod_names with
  | [] => tmReturn []
  | m :: rest =>
    tmBind (tmQuoteModule m) (fun refs =>
      tmBind (quote_module_refs rest) (fun acc =>
        tmReturn (List.app refs acc)))
  end.

(** Multi-module entry point. Closes §2 of the upstream requirements
    at the Fixpoint / constant level too: the user passes every
    module whose constants (Fixpoints, trusted predicates) should
    appear in the engine, not just the one whose inductives are the
    top-level query target.

    Inductives are still discovered transitively via close_kns; only
    constants need to be enumerated by module. *)
Definition hallmark_modules (mod_names : list qualid) : TemplateMonad string :=
  tmBind clpfd_defaults (fun tbl =>
  tmBind arith_defaults (fun arith =>
  tmBind (tmQuote True) (fun true_tm =>
  tmBind (tmQuote False) (fun false_tm =>
  tmBind (quote_module_refs mod_names) (fun refs =>
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
      tmBind (close_kns 1000 [] all_kns) (fun decls =>
        let Σ := build_env decls in
        let all_inds := inds_of_decls decls in
        let ind_clauses := translate_all tbl arith Σ all_inds in
        let fix_clauses :=
          translate_all_fixpoints tbl arith Σ true_kn false_kn fixpoints in
        let all_clauses := List.app ind_clauses fix_clauses in
        match all_clauses, trusted with
        | [], [] =>
          tmFail "No inductives, fixpoints, or trusted predicates found in modules"%bs
        | _, _ => tmReturn (print_program trusted all_clauses)
        end))))))).

(** Backward-compatible single-module wrapper. *)
Definition hallmark_module (mod_name : qualid) : TemplateMonad string :=
  hallmark_modules [mod_name].
