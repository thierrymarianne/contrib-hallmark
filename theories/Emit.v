(** * Emit — pretty-print Prolog clauses as source text

    Converts the [clause] IR into concrete Prolog syntax.
    - [print_term]: renders a [prolog_term] as text
    - [print_clause]: renders a [clause] as a Horn clause
    - [print_program]: assembles clauses into a complete Prolog source *)

From MetaRocq.Template Require Import All.
From MetaRocq.Utils Require Import bytestring MRString.
From Hallmark Require Import Clause.
From Stdlib Require Import List Bool PeanoNat.
Import ListNotations.

Local Open Scope bs_scope.

(** Collect all variable indices from a term. *)
Fixpoint collect_vars (t : prolog_term) : list nat :=
  match t with
  | PVar n => [n]
  | PAtom _ => []
  | PApp _ args => flat_map collect_vars args
  | PConstraint _ l r => collect_vars l ++ collect_vars r
  end.

(** Count occurrences of [n] in a list. *)
Fixpoint count (n : nat) (l : list nat) : nat :=
  match l with
  | [] => 0
  | x :: rest => (if Nat.eqb x n then 1 else 0) + count n rest
  end.

(** Render a Prolog term. Singleton variables (appearing once in the
    clause) are printed as [_]; others as [X0], [X1], etc. *)
Fixpoint print_term_ctx (vars : list nat) (t : prolog_term) : string :=
  match t with
  | PVar n => if count n vars =? 1 then "_" else "X" ++ string_of_nat n
  | PAtom a => a
  | PApp f args =>
    f ++ "(" ++
    (fix go (l : list prolog_term) : string :=
      match l with
      | [] => ""
      | [x] => print_term_ctx vars x
      | x :: rest => print_term_ctx vars x ++ ", " ++ go rest
      end) args ++ ")"
  | PConstraint op l r =>
    "clpfd_check(" ++ print_term_ctx vars l ++ " " ++ op ++ " "
                   ++ print_term_ctx vars r ++ ")"
  end.

(** Render a term without singleton analysis (for standalone use). *)
Definition print_term (t : prolog_term) : string :=
  print_term_ctx [] t.

(** Does a term contain any [PVar]? *)
Fixpoint has_var (t : prolog_term) : bool :=
  match t with
  | PVar _ => true
  | PAtom _ => false
  | PApp _ args =>
    (fix any (l : list prolog_term) : bool :=
      match l with
      | [] => false
      | x :: rest => has_var x || any rest
      end) args
  | PConstraint _ l r => has_var l || has_var r
  end.

(** Render a clause.  Every clause carries a [rule(name)] tag for audit
    trail and witness reconstruction. Singleton variables print as [_]. *)
Definition print_clause (c : clause) : string :=
  let all_vars := List.app (collect_vars (cl_head c))
                           (flat_map collect_vars (cl_body c)) in
  let pt := print_term_ctx all_vars in
  let head := pt (cl_head c) in
  let rule_tag := pt (PApp "rule" [PAtom (cl_name c)]) in
  match cl_body c with
  | [] => head ++ " :- " ++ rule_tag ++ "."
  | body =>
    head ++ " :- " ++ rule_tag ++ ", " ++
    String.concat ", " (map pt body) ++ "."
  end.

(** Render a [ctor_witness/4] fact for proof-witness reconstruction.

    Emits: [ctor_witness(Name, Head, [Body...], app(Name, [Args...])).]
    where [Args] interleaves data variables and [pf(I)] proof slots. *)
Definition print_ctor_witness (c : clause) : string :=
  let all_vars := List.app (collect_vars (cl_head c))
                    (List.app (flat_map collect_vars (cl_body c))
                              (flat_map collect_vars (cl_witness_args c))) in
  let pt := print_term_ctx all_vars in
  let head := pt (cl_head c) in
  let body_strs := map pt (cl_body c) in
  let arg_strs := map pt (cl_witness_args c) in
  "ctor_witness(" ++ cl_name c ++ ", " ++
    head ++ ", " ++
    "[" ++ String.concat ", " body_strs ++ "], " ++
    "app(" ++ cl_name c ++ ", [" ++ String.concat ", " arg_strs ++ "])).".

(** Check whether [pre] is a prefix of [s]. *)
Fixpoint is_prefix (pre s : string) : bool :=
  match pre, s with
  | String.EmptyString, _ => true
  | String.String a pre', String.String b s' =>
    if Byte.eqb a b then is_prefix pre' s' else false
  | _, _ => false
  end.

(** Check whether [sub] appears anywhere in [s]. *)
Fixpoint is_substring (sub s : string) : bool :=
  is_prefix sub s ||
  match s with
  | String.EmptyString => false
  | String.String _ s' => is_substring sub s'
  end.

(** Does a term use a CLP constraint? *)
Definition is_constraint (t : prolog_term) : bool :=
  match t with
  | PConstraint _ _ _ => true
  | _ => false
  end.

(** Does any clause in the program use CLP(FD) constraints? *)
Definition has_clpfd (clauses : list clause) : bool :=
  existsb (fun c => existsb is_constraint (cl_body c)) clauses.

(** Assemble a complete Prolog program.

    The [rule(_).] fact at the top ensures that [rule(Name)] — inserted
    as the first body atom of every clause by [print_clause] — always
    succeeds.  The [ctor_witness/4] facts enable proof-witness
    reconstruction: mapping resolution traces back to Rocq proof terms.
    When CLP(FD) constraints are present, [:- use_module(library(clpfd)).]
    is prepended. *)
Definition print_program (clauses : list clause) : string :=
  let clp_header :=
    if has_clpfd clauses
    then ":- use_module(library(clpfd))." ++ nl
    else "" in
  clp_header ++
  "rule(_)." ++ nl ++
  String.concat nl (map print_clause clauses) ++ nl ++
  String.concat nl (map print_ctor_witness clauses) ++ nl.
