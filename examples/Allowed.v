Inductive user := admin | alice | bob | eve | stranger.
Inductive resource := public_doc | secret_report | classified.

Inductive manager_of : user -> user -> Prop :=
  | mgr_alice_bob : manager_of alice bob
  | mgr_eve_alice : manager_of eve alice.

Inductive public : resource -> Prop :=
  | pub_doc : public public_doc.

Inductive allowed : user -> resource -> Prop :=
  | admin_all : forall r, allowed admin r
  | read_public : forall u r, public r -> allowed u r
  | delegate : forall u d r,
      manager_of u d -> allowed d r -> allowed u r.
