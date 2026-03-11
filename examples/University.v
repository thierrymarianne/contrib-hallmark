Inductive student := alice | bob | charlie | diana | eve | frank.
Inductive course := math101 | cs201 | cs301 | cs401 | thesis.

Inductive completed : student -> course -> Prop :=
  | alice_math   : completed alice math101
  | alice_cs201  : completed alice cs201
  | bob_math     : completed bob math101
  | bob_cs201    : completed bob cs201
  | bob_cs301    : completed bob cs301
  | charlie_math : completed charlie math101.

Inductive prerequisite : course -> course -> Prop :=
  | pre_cs201  : prerequisite math101 cs201
  | pre_cs301  : prerequisite cs201 cs301
  | pre_cs401  : prerequisite cs301 cs401
  | pre_thesis : prerequisite cs401 thesis.

(* Advisor chain: alice -> charlie -> diana -> frank *)
Inductive advisor : student -> student -> Prop :=
  | adv_alice_charlie : advisor alice charlie
  | adv_charlie_diana : advisor charlie diana
  | adv_diana_frank   : advisor diana frank
  | adv_bob_eve       : advisor bob eve.

Inductive waiver : student -> course -> Prop :=
  | waiver_eve_cs301 : waiver eve cs301.

Inductive eligible : student -> course -> Prop :=
  | by_prereq  : forall s c p,
      prerequisite p c -> completed s p -> eligible s c
  | by_advisor  : forall s a c,
      advisor a s -> eligible a c -> eligible s c
  | by_waiver   : forall s c,
      waiver s c -> eligible s c.

(* A student can TA a course they completed if they're also eligible
   for the next course in the chain — ensures they understand the
   broader curriculum. *)
Inductive can_ta : student -> course -> Prop :=
  | ta_qualified : forall s taught next,
      completed s taught ->
      prerequisite taught next ->
      eligible s next ->
      can_ta s taught.
