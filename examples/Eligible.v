Inductive person := alice | bob | charlie | diana.

Inductive age_of : person -> nat -> Prop :=
  | age_alice   : age_of alice 30
  | age_bob     : age_of bob 70
  | age_charlie : age_of charlie 10
  | age_diana   : age_of diana 50.

Inductive eligible : person -> nat -> Prop :=
  | senior : forall p age,
      age_of p age -> 65 <= age -> eligible p age
  | minor  : forall p age,
      age_of p age -> age < 18 -> eligible p age.

Inductive score_of : person -> nat -> Prop :=
  | sc_alice : score_of alice 85
  | sc_bob   : score_of bob 42
  | sc_diana : score_of diana 50.

Inductive passes : person -> nat -> Prop :=
  | by_ge : forall p s, score_of p s -> s >= 50 -> passes p s.

Inductive above : person -> nat -> Prop :=
  | by_gt : forall p s, score_of p s -> s > 80 -> above p s.

Inductive exact_score : person -> nat -> Prop :=
  | by_eq : forall p s, score_of p s -> s = 50 -> exact_score p s.
