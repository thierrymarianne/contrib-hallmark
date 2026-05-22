(** * TranslateFixpoint — Rocq Fixpoint to Prolog clauses

    Translates simple structural [Fixpoint] definitions returning [Prop]
    into Prolog clauses: one clause per [match] branch.

    Supported fragment:
      [Fixpoint f a1 ... an : Prop := match ai with | C1 ... => body1 | ... end.]

    Strategy:
    1. [subst0] replaces the [tFix] self-reference with a synthetic [tInd],
       so existing [classify_binding] recognizes recursive calls as [BRecursive].
    2. Strip [tLambda] binders to recover the argument list.
    3. Unwrap the [tCase] to get branches.
    4. For each branch, [parse_telescope] + [classify_all] + [extract_body_at]
       reuse the inductive translation machinery with a depth offset. *)

From MetaRocq.Template Require Import All.
From MetaRocq.Utils Require Import bytestring MRString.
From MetaRocq.Common Require Import Kernames.
From Hallmark Require Import Clause Telescope Classify Lookup Translate Clp.
From Stdlib Require Import List PeanoNat.
Import ListNotations.

Local Open Scope bs_scope.

(** Unwrap a chain of [tLambda] binders, returning the binding list
    and the inner body (analogous to [parse_telescope] for [tProd]). *)
Fixpoint strip_lambdas (t : term) : list (aname * term) * term :=
  match t with
  | tLambda na ty body =>
    let '(binds, inner) := strip_lambdas body in
    ((na, ty) :: binds, inner)
  | _ => ([], t)
  end.

(** Components extracted from a simple structural Fixpoint. *)
Record fixpoint_info := {
  fix_kn       : kername;
  fix_name     : ident;
  fix_args     : list (aname * term);
  fix_ci       : case_info;
  fix_branches : list (branch term);
  fix_matched  : nat;
}.

(** Detect whether a constant body is a simple structural Fixpoint:
    single non-mutual [tFix], body is lambdas + a single [tCase].
    Returns extracted components with the self-reference already
    eliminated via [subst0]. *)
Definition analyze_fixpoint (kn : kername) (cb : constant_body)
  : option fixpoint_info :=
  match cst_body cb with
  | Some (tFix [def] 0) =>
    let body := subst0 [tInd (mkInd kn 0) []] (dbody def) in
    let '(args, inner) := strip_lambdas body in
    match inner with
    | tCase ci _ _ branches =>
      Some {| fix_kn       := kn;
              fix_name     := snd kn;
              fix_args     := args;
              fix_ci       := ci;
              fix_branches := branches;
              fix_matched  := rarg def |}
    | _ => None
    end
  | _ => None
  end.

(** Generate [PVar N, PVar (N+1), ..., PVar (N+K-1)]. *)
Fixpoint pvar_range (start len : nat) : list prolog_term :=
  match len with
  | 0 => []
  | S k => PVar start :: pvar_range (S start) k
  end.

(** Build the clause head for a Fixpoint branch.

    Variable numbering (canonical positions):
    - Lambda arg at position [j] (j <> matched) gets [PVar j].
    - The matched position gets [PApp ctor_name [PVar N, ..., PVar (N+K-1)]]
      where pattern variables are in constructor declaration order
      (reversed bcontext / context order). *)
Definition build_fix_head (fix_name : ident) (nargs : nat) (matched : nat)
  (ctor_name : ident) (bctx_len : nat) : prolog_term :=
  let pattern_vars := pvar_range nargs bctx_len in
  let ctor_pat :=
    match pattern_vars with
    | [] => PAtom ctor_name
    | _  => PApp ctor_name pattern_vars
    end in
  let fix go (j remaining : nat) : list prolog_term :=
    match remaining with
    | 0 => []
    | S r =>
      (if Nat.eqb j matched then ctor_pat else PVar j)
        :: go (S j) r
    end in
  PApp fix_name (go 0 nargs).

(** Check whether a term is [tInd] for a given kername. *)
Definition is_ind_kn (kn : kername) (t : term) : bool :=
  match t with
  | tInd (mkInd kn' _) _ => kn == kn'
  | _ => false
  end.

(** Translate the return term of a branch body.
    - [True] / sort → [Some None] (no extra goal)
    - [False] → [None] (skip the whole branch)
    - predicate application → [Some (Some goal)] *)
Definition translate_return (Σ : global_env) (fix_kn : kername)
  (true_kn false_kn : kername) (depth : nat) (ret : term)
  : option (option prolog_term) :=
  if is_ind_kn true_kn ret then Some None
  else if is_ind_kn false_kn ret then None
  else if is_sort ret then Some None
  else
    match is_ind_app fix_kn ret with
    | Some args => Some (Some (PApp (snd fix_kn) (args_to_prolog Σ depth args)))
    | None =>
      match get_app_head ret with
      | Some (kn, args) =>
        Some (Some (PApp (snd kn) (args_to_prolog Σ depth args)))
      | None => Some None
      end
    end.

(** Translate one [tCase] branch into a Prolog clause.

    De Bruijn context inside the branch body (outermost → innermost):
    - positions 0..N-1: lambda arguments
    - positions N..N+K-1: bcontext pattern variables
    - positions N+K..: premise bindings from [parse_telescope]

    [extract_body_at] starts its depth counter at [offset = N + K]. *)
Definition translate_branch (tbl : clp_table) (Σ : global_env)
  (fix_kn : kername) (true_kn false_kn : kername) (fix_name : ident)
  (nargs : nat) (matched : nat) (ctor_name : ident) (br : branch term)
  : option clause :=
  let bctx_len := length (bcontext br) in
  let offset := nargs + bctx_len in
  let '(bindings, ret) := parse_telescope (bbody br) in
  let total := offset + length bindings in
  let classes := classify_all tbl fix_kn bindings in
  let body := extract_body_at Σ fix_kn offset classes in
  let cl_name := fix_name ++ "_" ++ ctor_name in
  let head := build_fix_head fix_name nargs matched ctor_name bctx_len in
  match translate_return Σ fix_kn true_kn false_kn total ret with
  | None => None
  | Some None =>
    Some {| cl_name := cl_name; cl_head := head; cl_body := body;
            cl_witness_args := []; cl_npremises := Some (length body) |}
  | Some (Some extra_goal) =>
    Some {| cl_name := cl_name; cl_head := head;
            cl_body := List.app body [extra_goal];
            cl_witness_args := []; cl_npremises := Some (length body) |}
  end.

(** Translate a complete Fixpoint into Prolog clauses. *)
Definition translate_fixpoint (tbl : clp_table) (Σ : global_env)
  (true_kn false_kn : kername) (fi : fixpoint_info) : list clause :=
  let nargs := length (fix_args fi) in
  let matched := fix_matched fi in
  let matched_ind := ci_ind (fix_ci fi) in
  let fix go (idx : nat) (brs : list (branch term)) : list clause :=
    match brs with
    | [] => []
    | br :: rest =>
      match lookup_constructor_name Σ matched_ind idx with
      | Some cname =>
        match translate_branch tbl Σ (fix_kn fi) true_kn false_kn
                (fix_name fi) nargs matched cname br with
        | Some c => c :: go (S idx) rest
        | None => go (S idx) rest
        end
      | None => go (S idx) rest
      end
    end in
  go 0 (fix_branches fi).
