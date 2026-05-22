(* ================================================================
   Fantasy — a rich adventure domain showcasing Hallmark features:
   enum types, static knowledge, trusted predicates, CLP(FD),
   multi-premise rules, and structural Fixpoints.
   ================================================================ *)

(* === Entity types === *)

Inductive hero :=
  aria | bron | cael | dara | elis | finn
  | gwen | hale | iris | jace | kira | luna.

Inductive element := fire | ice | lightning | earth | shadow | light.

Inductive region :=
  village | forest | cave | mountain | swamp
  | volcano | ruins | tower | lake | abyss.

Inductive monster :=
  goblin | wolf | troll | wyrm | specter
  | drake | lich | golem | hydra | phoenix.

Inductive item :=
  sword | shield | bow | staff | cloak
  | lantern | rope | key_stone | elixir | amulet | tome.

(* === Static knowledge === *)

Inductive weakness : monster -> element -> Prop :=
  | w_goblin_fire      : weakness goblin fire
  | w_wolf_fire        : weakness wolf fire
  | w_troll_fire       : weakness troll fire
  | w_wyrm_ice         : weakness wyrm ice
  | w_specter_light    : weakness specter light
  | w_drake_ice        : weakness drake ice
  | w_lich_light       : weakness lich light
  | w_lich_fire        : weakness lich fire
  | w_golem_lightning  : weakness golem lightning
  | w_hydra_lightning  : weakness hydra lightning
  | w_hydra_fire       : weakness hydra fire
  | w_phoenix_ice      : weakness phoenix ice.

Inductive connects : region -> region -> Prop :=
  | c_village_forest   : connects village forest
  | c_forest_cave      : connects forest cave
  | c_forest_swamp     : connects forest swamp
  | c_cave_mountain    : connects cave mountain
  | c_mountain_volcano : connects mountain volcano
  | c_swamp_ruins      : connects swamp ruins
  | c_ruins_tower      : connects ruins tower
  | c_village_lake     : connects village lake
  | c_lake_swamp       : connects lake swamp
  | c_tower_abyss      : connects tower abyss
  | c_volcano_abyss    : connects volcano abyss.

Inductive inhabits : monster -> region -> Prop :=
  | i_goblin_forest    : inhabits goblin forest
  | i_wolf_forest      : inhabits wolf forest
  | i_wolf_cave        : inhabits wolf cave
  | i_troll_cave       : inhabits troll cave
  | i_troll_swamp      : inhabits troll swamp
  | i_wyrm_mountain    : inhabits wyrm mountain
  | i_specter_ruins    : inhabits specter ruins
  | i_specter_tower    : inhabits specter tower
  | i_drake_volcano    : inhabits drake volcano
  | i_lich_tower       : inhabits lich tower
  | i_golem_ruins      : inhabits golem ruins
  | i_hydra_swamp      : inhabits hydra swamp
  | i_hydra_lake       : inhabits hydra lake
  | i_phoenix_volcano  : inhabits phoenix volcano.

Inductive power : monster -> nat -> Prop :=
  | p_goblin  : power goblin 3
  | p_wolf    : power wolf 5
  | p_troll   : power troll 10
  | p_wyrm    : power wyrm 15
  | p_specter : power specter 12
  | p_drake   : power drake 20
  | p_lich    : power lich 25
  | p_golem   : power golem 18
  | p_hydra   : power hydra 22
  | p_phoenix : power phoenix 30.

Inductive min_level : region -> nat -> Prop :=
  | ml_village  : min_level village 1
  | ml_forest   : min_level forest 1
  | ml_lake     : min_level lake 3
  | ml_cave     : min_level cave 5
  | ml_swamp    : min_level swamp 8
  | ml_mountain : min_level mountain 12
  | ml_ruins    : min_level ruins 10
  | ml_volcano  : min_level volcano 18
  | ml_tower    : min_level tower 15
  | ml_abyss    : min_level abyss 25.

Inductive grants_access : item -> region -> Prop :=
  | ga_lantern_cave    : grants_access lantern cave
  | ga_rope_mountain   : grants_access rope mountain
  | ga_cloak_swamp     : grants_access cloak swamp
  | ga_key_tower       : grants_access key_stone tower
  | ga_amulet_ruins    : grants_access amulet ruins
  | ga_tome_abyss      : grants_access tome abyss.

(* === Dynamic state (trusted predicates) === *)

Definition has_item (h : hero) (i : item) : Prop := True.
Definition level (h : hero) (n : nat) : Prop := True.
Definition attuned (h : hero) (e : element) : Prop := True.

(* === Derived rules === *)

Inductive can_damage : hero -> monster -> Prop :=
  | exploit_weakness : forall h m e,
      attuned h e -> weakness m e -> can_damage h m.

Inductive can_enter : hero -> region -> Prop :=
  | enter_by_level : forall h r l n,
      level h l -> min_level r n -> n <= l -> can_enter h r
  | enter_by_item : forall h r i,
      has_item h i -> grants_access i r -> can_enter h r.

Inductive can_defeat : hero -> monster -> Prop :=
  | overpower : forall h m l p,
      can_damage h m -> level h l -> power m p -> p <= l ->
      can_defeat h m.

Inductive can_hunt : hero -> monster -> region -> Prop :=
  | hunt : forall h m r,
      can_enter h r -> inhabits m r -> can_defeat h m ->
      can_hunt h m r.

(* === Path reachability === *)

Inductive trail :=
  | arrive : region -> trail
  | through : region -> trail -> trail.

Fixpoint traversable (start : region) (t : trail) : Prop :=
  match t with
  | arrive dest => connects start dest
  | through mid rest => connects start mid -> traversable mid rest
  end.
