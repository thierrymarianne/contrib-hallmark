Inductive person := alice | bob | charlie.

(* Trusted predicate: facts live on the Prolog side. *)
Definition likes (p1 p2 : person) : Prop := True.

Inductive popular : person -> Prop :=
  | well_liked : forall p q r,
      likes q p -> likes r p -> popular p.
