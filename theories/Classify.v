(** * Classify — categorize constructor-type bindings

    Each binding in a constructor telescope is classified as one of:
    - [BIndex]:     a universally quantified variable (becomes a Prolog variable)
    - [BRecursive]: a premise that applies the inductive being translated
    - [BExternal]:  a premise that applies a different predicate
    - [BErased]:    a sort/universe binder (Type, Prop, etc.) — dropped

    Named binders ([forall x : T, ...]) are treated as value variables.
    Anonymous binders ([T -> ...]) are treated as premises. *)

From MetaRocq.Template Require Import All.
From MetaRocq.Common Require Import Kernames.
From Hallmark Require Import Clp.
From Stdlib Require Import List.
Import ListNotations.

Inductive binding_class :=
| BIndex
| BRecursive (args : list term)
| BExternal  (head : kername) (args : list term)
| BConstraint (op : ident) (args : list term)
| BErased.

(** True when [t] is a universe sort ([Type], [Prop], [Set]). *)
Definition is_sort (t : term) : bool :=
  match t with
  | tSort _ => true
  | _ => false
  end.

(** If [t] is an application of the inductive [ind_kn], return its arguments. *)
Definition is_ind_app (ind_kn : kername) (t : term) : option (list term) :=
  let '(hd, args) := decompose_app t in
  match hd with
  | tInd (mkInd kn _) _ =>
    if eq_kername kn ind_kn then Some args else None
  | _ => None
  end.

(** Extract the head kername and arguments from an applied inductive or constant. *)
Definition get_app_head (t : term) : option (kername * list term) :=
  let '(hd, args) := decompose_app t in
  match hd with
  | tInd (mkInd kn _) _ => Some (kn, args)
  | tConst kn _ => Some (kn, args)
  | _ => None
  end.

(** Classify a single binding.
    Named binders are value variables; anonymous binders are premises.
    If the head kername appears in [tbl], the binding becomes a
    [BConstraint] — emitted as a CLP(FD) infix operator. *)
Definition classify_binding (tbl : clp_table) (ind_kn : kername)
  (na : aname) (ty : term) : binding_class :=
  if is_sort ty then BErased
  else match is_ind_app ind_kn ty with
  | Some args => BRecursive args
  | None =>
    match binder_name na with
    | nNamed _ => BIndex
    | nAnon =>
      match get_app_head ty with
      | Some (kn, args) =>
        match clp_lookup tbl kn with
        | Some op => BConstraint op args
        | None    => BExternal kn args
        end
      | None => BIndex
      end
    end
  end.

(** Classify every binding in a telescope. *)
Definition classify_all (tbl : clp_table) (ind_kn : kername)
  (bindings : list (aname * term)) : list binding_class :=
  map (fun '(na, ty) => classify_binding tbl ind_kn na ty) bindings.
