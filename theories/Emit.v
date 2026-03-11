(** * Emit — pretty-print Prolog clauses as source text

    Converts the [clause] IR into concrete Prolog syntax.
    - [print_term]: renders a [prolog_term] as text
    - [print_clause]: renders a [clause] as a Horn clause
    - [print_program]: assembles clauses into a complete Prolog source *)

From MetaRocq.Template Require Import All.
From MetaRocq.Utils Require Import bytestring MRString.
From Hallmark Require Import Clause.
From Stdlib Require Import List.
Import ListNotations.

Local Open Scope bs_scope.

(** Render a Prolog term: [PVar n] -> "Xn", [PAtom a] -> "a",
    [PApp f args] -> "f(a1, a2, ...)". *)
Fixpoint print_term (t : prolog_term) : string :=
  match t with
  | PVar n => "X" ++ string_of_nat n
  | PAtom a => a
  | PApp f args =>
    f ++ "(" ++
    (fix go (l : list prolog_term) : string :=
      match l with
      | [] => ""
      | [x] => print_term x
      | x :: rest => print_term x ++ ", " ++ go rest
      end) args ++ ")"
  end.

(** Render a clause. Every clause includes [rule(name)] as
    the first body atom for traceability. *)
Definition print_clause (c : clause) : string :=
  let head := print_term (cl_head c) in
  let rule_tag := print_term (PApp "rule" [PAtom (cl_name c)]) in
  match cl_body c with
  | [] => head ++ " :- " ++ rule_tag ++ "."
  | body =>
    head ++ " :- " ++ rule_tag ++ ", " ++
    String.concat ", " (map print_term body) ++ "."
  end.

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

(** Assemble a complete Prolog program.

    The [rule(_).] fact at the top ensures that [rule(Name)] — inserted
    as the first body atom of every clause by [print_clause] — always
    succeeds. This lets users inspect which constructor fired during a
    derivation (e.g. via [clause/2]) without adding runtime cost. *)
Definition print_program (clauses : list clause) : string :=
  "rule(_)." ++ nl ++ String.concat nl (map print_clause clauses) ++ nl.
