Inductive person := alice | bob | charlie.

Inductive knows : person -> person -> Prop :=
  | kab : knows alice bob
  | kbc : knows bob charlie.

Inductive chain :=
  | here : person -> chain
  | step : person -> chain -> chain.

Fixpoint reachable (start : person) (c : chain) : Prop :=
  match c with
  | here dest => knows start dest
  | step mid rest => knows start mid -> reachable mid rest
  end.
