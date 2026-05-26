(** * Clp — CLP(FD) constraint registration

    Maps Rocq proposition heads (kernames) to CLP(FD) operators.
    The translator consults this table during classification:
    if a binding's head kername appears in the table, the binding
    is emitted as a CLP(FD) infix constraint instead of a plain atom.

    Standard mappings are built via [clpfd_defaults], which uses
    MetaRocq quoting to discover the actual kernames at elaboration
    time (avoiding hard-coded module paths). *)

From MetaRocq.Template Require Import All.
From MetaRocq.Utils Require Import bytestring.
From Stdlib Require Import List.
Import ListNotations.

Local Open Scope bs_scope.

Record clp_mapping := {
  clp_head : kername;
  clp_op   : ident;
}.

Definition clp_table := list clp_mapping.

(** Look up a kername in the CLP table. *)
Definition clp_lookup (tbl : clp_table) (kn : kername) : option ident :=
  let fix go (l : clp_table) :=
    match l with
    | [] => None
    | m :: rest =>
      if kn == clp_head m then Some (clp_op m)
      else go rest
    end
  in go tbl.

(** Extract the head kername from a quoted proposition.
    Handles both inductives ([tInd]) and constants ([tConst]). *)
Definition extract_head_kn (t : term) : option kername :=
  let '(hd, _) := decompose_app t in
  match hd with
  | tInd (mkInd kn _) _ => Some kn
  | tConst kn _          => Some kn
  | _                     => None
  end.

(** Register a single CLP(FD) mapping by quoting a dummy proposition
    to discover the head kername. *)
Definition register_clpfd (op : ident) (prop_term : term) : option clp_mapping :=
  match extract_head_kn prop_term with
  | Some kn => Some {| clp_head := kn; clp_op := op |}
  | None    => None
  end.

(** Build the standard CLP(FD) table at elaboration time.
    Quotes comparison propositions to discover their kernames. *)
Definition clpfd_defaults : TemplateMonad clp_table :=
  tmBind (tmQuote (0 <= 0)) (fun le_tm =>
  tmBind (tmQuote (0 < 0))  (fun lt_tm =>
  tmBind (tmQuote (0 >= 0)) (fun ge_tm =>
  tmBind (tmQuote (0 > 0))  (fun gt_tm =>
  tmBind (tmQuote (0 = 0))  (fun eq_tm =>
    let entries := flat_map
      (fun x => match x with Some e => [e] | None => [] end)
      [ register_clpfd "#=<" le_tm
      ; register_clpfd "#<"  lt_tm
      ; register_clpfd "#>=" ge_tm
      ; register_clpfd "#>"  gt_tm
      ; register_clpfd "#="  eq_tm
      ] in
    tmReturn entries))))).

(** Same shape as [clp_table], but for binary arithmetic operators
    used INSIDE CLP constraint expressions (the [+], [-], [*] on
    either side of [<=], [=], etc.). The translator emits these as
    [PInfix] rather than [PApp] so that Prolog renders them with
    their native infix syntax (e.g. [X + Y #=< Z], not
    [add(X, Y) #=< Z]).

    Closes §4 of the hallmark upstream requirements (the arithmetic-
    with-Fixpoint-operands rendering as [?]). *)
Definition arith_table := list clp_mapping.

Definition arith_lookup (tbl : arith_table) (kn : kername) : option ident :=
  clp_lookup tbl kn.

(** Build the standard arithmetic table at elaboration time.
    Quotes [Nat.add], [Nat.sub], [Nat.mul] to discover their kernames. *)
Definition arith_defaults : TemplateMonad arith_table :=
  tmBind (tmQuote (Nat.add 0 0)) (fun add_tm =>
  tmBind (tmQuote (Nat.sub 0 0)) (fun sub_tm =>
  tmBind (tmQuote (Nat.mul 0 0)) (fun mul_tm =>
    let entries := flat_map
      (fun x => match x with Some e => [e] | None => [] end)
      [ register_clpfd "+" add_tm
      ; register_clpfd "-" sub_tm
      ; register_clpfd "*" mul_tm
      ] in
    tmReturn entries))).
