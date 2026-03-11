(** * Classify — categorize constructor-type bindings

    Each binding in a constructor telescope is classified as one of:
    - [BIndex]:     a universally quantified variable (becomes a Prolog variable)
    - [BRecursive]: a premise that applies the inductive being translated
    - [BExternal]:  a premise that applies a different predicate
    - [BErased]:    a sort/universe binder (Type, Prop, etc.) — dropped *)

From MetaRocq.Template Require Import All.
From MetaRocq.Common Require Import Kernames.
From Stdlib Require Import List.
Import ListNotations.

Inductive binding_class :=
| BIndex
| BRecursive (args : list term)
| BExternal  (head : kername) (args : list term)
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

(** Classify a single binding given the kername of the inductive being translated. *)
Definition classify_binding (ind_kn : kername) (ty : term) : binding_class :=
  if is_sort ty then BErased
  else match is_ind_app ind_kn ty with
  | Some args => BRecursive args
  | None =>
    match get_app_head ty with
    | Some (kn, args) => BExternal kn args
    | None => BIndex
    end
  end.

(** Classify every binding in a telescope. *)
Definition classify_all (ind_kn : kername) (bindings : list (aname * term))
  : list binding_class :=
  map (fun '(_, ty) => classify_binding ind_kn ty) bindings.
